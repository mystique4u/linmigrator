#!/bin/bash
# Export script - Collects complete system state from Ubuntu source
# Auto-detects mount points, packages, configurations
# Encrypts and stores in repository

set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║         LinMigrator - Export Script                       ║
║         System State Collector                            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running on Ubuntu
check_os() {
    if [ ! -f /etc/lsb-release ]; then
        print_error "This doesn't appear to be Ubuntu!"
        exit 1
    fi
    source /etc/lsb-release
    print_success "Running on Ubuntu $DISTRIB_RELEASE ($DISTRIB_CODENAME)"
}

# Generate unique export ID
generate_export_id() {
    local hostname=$(hostname -s)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${hostname}_${timestamp}"
}

# Generate encryption key
generate_encryption_key() {
    local key_file="$1"
    if [ -f "$key_file" ]; then
        print_warning "Key file already exists: $key_file"
        read -p "Generate new key? This will invalidate old exports! (y/N): " REGEN
        if [ "$REGEN" != "y" ]; then
            print_info "Using existing key"
            return 0
        fi
    fi
    
    print_info "Generating encryption key..."
    openssl rand -base64 32 > "$key_file"
    chmod 600 "$key_file"
    print_success "Encryption key generated: $key_file"
    print_warning "KEEP THIS KEY SAFE! You'll need it to decrypt exports."
}

# Detect all mount points
detect_mount_points() {
    print_info "Detecting mount points..."
    
    local output_file="$1"
    
    # Get all mount points excluding system/temporary ones
    mount | grep -vE '(tmpfs|devtmpfs|sysfs|proc|devpts|securityfs|cgroup|pstore|bpf|autofs|mqueue|debugfs|hugetlbfs|tracefs|fusectl|configfs|snap)' | \
    while read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mountpoint=$(echo "$line" | awk '{print $3}')
        local fstype=$(echo "$line" | awk '{print $5}')
        
        # Skip if it's the root filesystem or boot
        if [ "$mountpoint" = "/" ] || [ "$mountpoint" = "/boot" ] || [ "$mountpoint" = "/boot/efi" ]; then
            continue
        fi
        
        echo "$device|$mountpoint|$fstype"
    done > "$output_file"
    
    local count=$(wc -l < "$output_file")
    print_success "Detected $count non-system mount points"
    
    if [ $count -gt 0 ]; then
        echo ""
        print_info "Found mount points:"
        while IFS='|' read -r device mountpoint fstype; do
            echo "  $mountpoint ($fstype) on $device"
        done < "$output_file"
        echo ""
    fi
}

# Detect installed packages
detect_packages() {
    print_info "Collecting installed packages..."
    
    local export_dir="$1"
    
    # APT packages
    print_info "  - Scanning APT packages..."
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' > "$export_dir/packages_apt.txt"
    local apt_count=$(wc -l < "$export_dir/packages_apt.txt")
    print_success "  Found $apt_count APT packages"
    
    # Snap packages
    if command -v snap &> /dev/null; then
        print_info "  - Scanning Snap packages..."
        snap list 2>/dev/null | tail -n +2 | awk '{print $1}' > "$export_dir/packages_snap.txt" || true
        local snap_count=$(wc -l < "$export_dir/packages_snap.txt")
        print_success "  Found $snap_count Snap packages"
    fi
    
    # Flatpak packages
    if command -v flatpak &> /dev/null; then
        print_info "  - Scanning Flatpak packages..."
        flatpak list --app --columns=application 2>/dev/null > "$export_dir/packages_flatpak.txt" || true
        local flatpak_count=$(wc -l < "$export_dir/packages_flatpak.txt")
        print_success "  Found $flatpak_count Flatpak packages"
    fi
    
    # Manual packages (compile list of user-installed only)
    print_info "  - Identifying manually installed packages..."
    comm -23 <(apt-mark showmanual | sort) <(gzip -dc /var/log/installer/initial-status.gz 2>/dev/null | sed -n 's/^Package: //p' | sort) > "$export_dir/packages_manual.txt" 2>/dev/null || \
    apt-mark showmanual > "$export_dir/packages_manual.txt"
    local manual_count=$(wc -l < "$export_dir/packages_manual.txt")
    print_success "  Found $manual_count manually installed packages"
}

# Detect enabled services
detect_services() {
    print_info "Collecting enabled services..."
    
    local export_dir="$1"
    
    systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend | \
        awk '{print $1}' > "$export_dir/services_enabled.txt"
    
    local count=$(wc -l < "$export_dir/services_enabled.txt")
    print_success "Found $count enabled services"
}

# Detect users and groups
detect_users() {
    print_info "Collecting user information..."
    
    local export_dir="$1"
    
    # Regular users (UID >= 1000)
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1":"$3":"$4":"$6":"$7}' /etc/passwd > "$export_dir/users.txt"
    local count=$(wc -l < "$export_dir/users.txt")
    print_success "Found $count regular users"
    
    # Groups
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1":"$3":"$4}' /etc/group > "$export_dir/groups.txt"
}

# Detect GPU
detect_gpu() {
    print_info "Detecting GPU..."
    
    local export_dir="$1"
    local gpu_info=""
    
    if command -v lspci &> /dev/null; then
        gpu_info=$(lspci | grep -i vga)
        echo "$gpu_info" > "$export_dir/gpu_info.txt"
        
        if echo "$gpu_info" | grep -qi nvidia; then
            echo "nvidia" > "$export_dir/gpu_type.txt"
            print_success "Detected NVIDIA GPU"
        elif echo "$gpu_info" | grep -qi amd; then
            echo "amd" > "$export_dir/gpu_type.txt"
            print_success "Detected AMD GPU"
        elif echo "$gpu_info" | grep -qi intel; then
            echo "intel" > "$export_dir/gpu_type.txt"
            print_success "Detected Intel GPU"
        else
            echo "unknown" > "$export_dir/gpu_type.txt"
            print_info "GPU detected but type unknown"
        fi
    fi
}

# Detect desktop environment
detect_desktop() {
    print_info "Detecting desktop environment..."
    
    local export_dir="$1"
    local desktop=""
    
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        desktop="$XDG_CURRENT_DESKTOP"
    elif [ "$DESKTOP_SESSION" ]; then
        desktop="$DESKTOP_SESSION"
    elif command -v gnome-shell &> /dev/null; then
        desktop="GNOME"
    elif command -v plasmashell &> /dev/null; then
        desktop="KDE"
    fi
    
    echo "$desktop" > "$export_dir/desktop_environment.txt"
    print_success "Desktop: $desktop"
}

# Collect system information
collect_system_info() {
    print_info "Collecting system information..."
    
    local export_dir="$1"
    local info_file="$export_dir/system_info.txt"
    
    {
        echo "# System Information"
        echo "Export Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo ""
        echo "# OS Information"
        cat /etc/lsb-release
        echo ""
        echo "# Memory"
        free -h
        echo ""
        echo "# CPU"
        lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"
        echo ""
        echo "# Disk Usage"
        df -h
    } > "$info_file"
    
    print_success "System information collected"
}

# Create export configuration file (human-readable and editable)
create_export_config() {
    print_info "Creating export configuration..."
    
    local export_dir="$1"
    local config_file="$export_dir/export.conf"
    
    cat > "$config_file" << 'EOF'
# LinMigrator Export Configuration
# This file is human-readable and editable
# Comment out (#) any lines you don't want to import

# Export metadata
[metadata]
version=1.0.0
export_date=$(date +%Y-%m-%d)
source_hostname=$(hostname)
source_os=Ubuntu

# Import settings
[import_settings]
# Enable/disable import features
import_packages=true
import_services=true
import_users=false  # Usually you want to keep target system users
import_nvidia=auto  # auto, true, false
import_whitesur_theme=true
import_developer_tools=true

# Mount point settings
[mount_points]
# Auto-detected mount points will be listed here
# Format: device|mountpoint|fstype|import
# Set import=false to skip mounting a particular device

EOF

    # Add detected mount points
    if [ -f "$export_dir/mount_points.txt" ]; then
        while IFS='|' read -r device mountpoint fstype; do
            # Default to true for /home and /var, false for others
            local import_flag="false"
            if [ "$mountpoint" = "/home" ] || [ "$mountpoint" = "/var" ]; then
                import_flag="true"
            fi
            echo "${device}|${mountpoint}|${fstype}|${import_flag}" >> "$config_file"
        done < "$export_dir/mount_points.txt"
    fi
    
    print_success "Configuration file created: export.conf"
    print_info "You can edit this file before importing!"
}

# Encrypt export directory
encrypt_export() {
    print_info "Encrypting export..."
    
    local export_dir="$1"
    local key_file="$2"
    local export_id=$(basename "$export_dir")
    local archive_file="${export_dir}.tar.gz"
    local encrypted_file="${export_dir}.tar.gz.enc"
    
    # Create tar archive
    print_info "  Creating archive..."
    tar -czf "$archive_file" -C "$(dirname "$export_dir")" "$export_id"
    
    # Encrypt
    print_info "  Encrypting with AES-256..."
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$archive_file" -out "$encrypted_file" -pass file:"$key_file"
    
    # Remove unencrypted archive
    rm "$archive_file"
    
    # Remove unencrypted directory (keep encrypted version only in repo)
    rm -rf "$export_dir"
    
    print_success "Export encrypted: $(basename "$encrypted_file")"
    print_info "Size: $(du -h "$encrypted_file" | cut -f1)"
}

# Main execution
main() {
    print_header
    
    check_os
    
    # Check for required tools
    for tool in openssl tar git; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Generate unique export ID
    EXPORT_ID=$(generate_export_id)
    print_info "Export ID: $EXPORT_ID"
    
    # Create export directory
    EXPORT_DIR="$REPO_ROOT/exports/$EXPORT_ID"
    mkdir -p "$EXPORT_DIR"
    print_success "Export directory: $EXPORT_DIR"
    
    # Generate or use existing encryption key
    KEY_FILE="$HOME/.linmigrator_key"
    generate_encryption_key "$KEY_FILE"
    
    echo ""
    print_info "Starting system scan..."
    echo ""
    
    # Collect all information
    detect_mount_points "$EXPORT_DIR/mount_points.txt"
    detect_packages "$EXPORT_DIR"
    detect_services "$EXPORT_DIR"
    detect_users "$EXPORT_DIR"
    detect_gpu "$EXPORT_DIR"
    detect_desktop "$EXPORT_DIR"
    collect_system_info "$EXPORT_DIR"
    create_export_config "$EXPORT_DIR"
    
    # Create README for export
    cat > "$EXPORT_DIR/README.md" << EOF
# Export: $EXPORT_ID

**Date:** $(date)  
**Source:** $(hostname) (Ubuntu $(lsb_release -rs))  
**Version:** $VERSION

## Contents

- \`export.conf\` - Main configuration (editable!)
- \`packages_*.txt\` - Package lists
- \`mount_points.txt\` - Detected mount points
- \`services_enabled.txt\` - Enabled services
- \`users.txt\`, \`groups.txt\` - User information
- \`gpu_*.txt\` - GPU information
- \`system_info.txt\` - System details

## Usage

1. Copy encryption key: \`~/.linmigrator_key\`
2. Clone repo on target system
3. Decrypt: \`./scripts/import.sh $EXPORT_ID\`
4. Edit \`export.conf\` if needed
5. Run import

## Notes

Edit \`export.conf\` to customize what gets imported.
Comment out packages you don't want in package files.
EOF
    
    echo ""
    print_info "Encrypting export..."
    encrypt_export "$EXPORT_DIR" "$KEY_FILE"
    
    ENCRYPTED_FILE="$REPO_ROOT/exports/${EXPORT_ID}.tar.gz.enc"
    
    echo ""
    print_success "═══════════════════════════════════════════════════════"
    print_success "Export Complete!"
    print_success "═══════════════════════════════════════════════════════"
    echo ""
    echo "Export file: $(basename "$ENCRYPTED_FILE")"
    echo "Encryption key: $KEY_FILE"
    echo ""
    print_warning "IMPORTANT: Save your encryption key!"
    echo ""
    echo "  cp $KEY_FILE /path/to/safe/location/"
    echo ""
    print_info "Add to GitHub Secrets:"
    echo "  1. Go to repo Settings → Secrets and variables → Actions"
    echo "  2. New repository secret: LINMIGRATOR_KEY"
    echo "  3. Paste content of: cat $KEY_FILE"
    echo ""
    
    # Offer to commit and push
    read -p "Commit and push to repository? (y/N): " PUSH
    if [ "$PUSH" = "y" ] || [ "$PUSH" = "Y" ]; then
        cd "$REPO_ROOT"
        git add "exports/${EXPORT_ID}.tar.gz.enc"
        git commit -m "Add encrypted export: $EXPORT_ID

Source: $(hostname)
Date: $(date +%Y-%m-%d)
Packages: $(wc -l < "$EXPORT_DIR/packages_manual.txt" 2>/dev/null || echo 0) manual
Mount points: $(wc -l < "$EXPORT_DIR/mount_points.txt" 2>/dev/null || echo 0)"
        git push origin main
        print_success "Pushed to repository!"
    fi
    
    echo ""
    print_success "Done! 🎉"
}

main "$@"
