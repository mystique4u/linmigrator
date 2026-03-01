#!/bin/bash
# Import script - Bootstraps Fedora and imports Ubuntu configuration
# Decrypts export, installs Ansible, runs migration

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
║         LinMigrator - Import Script                       ║
║         Bootstrap & Configuration Importer                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running on Fedora
check_os() {
    if [ ! -f /etc/fedora-release ]; then
        print_error "This script must run on Fedora!"
        exit 1
    fi
    print_success "Running on Fedora $(cat /etc/fedora-release)"
}

# List available exports
list_exports() {
    local exports_dir="$REPO_ROOT/exports"
    
    if [ ! -d "$exports_dir" ] || [ -z "$(ls -A "$exports_dir" 2>/dev/null)" ]; then
        print_error "No exports found in $exports_dir"
        exit 1
    fi
    
    print_info "Available exports:"
    echo ""
    local count=1
    for export_file in "$exports_dir"/*.tar.gz.enc; do
        if [ -f "$export_file" ]; then
            local basename=$(basename "$export_file" .tar.gz.enc)
            local size=$(du -h "$export_file" | cut -f1)
            echo "  $count) $basename ($size)"
            ((count++))
        fi
    done
    echo ""
}

# Decrypt export
decrypt_export() {
    local export_id="$1"
    local key_file="$2"
    local encrypted_file="$REPO_ROOT/exports/${export_id}.tar.gz.enc"
    local decrypted_file="$REPO_ROOT/exports/${export_id}.tar.gz"
    local export_dir="$REPO_ROOT/exports/${export_id}"
    
    if [ ! -f "$encrypted_file" ]; then
        print_error "Export not found: $encrypted_file"
        exit 1
    fi
    
    if [ ! -f "$key_file" ]; then
        print_error "Encryption key not found: $key_file"
        print_info "Please place your key at: $key_file"
        exit 1
    fi
    
    print_info "Decrypting export..."
    openssl enc -aes-256-cbc -d -pbkdf2 -in "$encrypted_file" -out "$decrypted_file" -pass file:"$key_file"
    
    print_info "Extracting archive..."
    tar -xzf "$decrypted_file" -C "$REPO_ROOT/exports/"
    
    rm "$decrypted_file"
    
    print_success "Export decrypted: $export_dir"
    echo "$export_dir"
}

# Bootstrap Fedora
bootstrap_fedora() {
    print_info "Bootstrapping Fedora system..."
    
    # Update system
    print_info "  Updating system packages..."
    sudo dnf update -y -q
    
    # Install essential tools
    print_info "  Installing essential packages..."
    sudo dnf install -y \
        python3 \
        python3-pip \
        python3-dnf \
        libselinux-python3 \
        git \
        wget \
        curl \
        openssl \
        tar \
        gzip
    
    # Install Ansible
    print_info "  Installing Ansible..."
    sudo dnf install -y ansible
    
    # Install Python packages
    print_info "  Installing Python dependencies..."
    pip3 install --user jmespath 2>/dev/null || true
    
    print_success "Bootstrap complete!"
}

# Load export configuration
load_export_config() {
    local export_dir="$1"
    local config_file="$export_dir/export.conf"
    
    if [ ! -f "$config_file" ]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_info "Loading export configuration..."
    
    # Allow user to edit
    print_info "Review/edit configuration before importing?"
    read -p "Open in editor? (y/N): " EDIT
    if [ "$EDIT" = "y" ] || [ "$EDIT" = "Y" ]; then
        ${EDITOR:-nano} "$config_file"
    fi
    
    # Source configuration
    source "$config_file"
    
    print_success "Configuration loaded"
}

# Create Ansible inventory
create_ansible_inventory() {
    print_info "Creating Ansible inventory..."
    
    mkdir -p "$REPO_ROOT/ansible"
    
    cat > "$REPO_ROOT/ansible/inventory.ini" << 'EOF'
[localhost]
127.0.0.1 ansible_connection=local

[localhost:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
    
    print_success "Inventory created"
}

# Generate dynamic Ansible variables from export
generate_ansible_vars() {
    local export_dir="$1"
    local vars_file="$REPO_ROOT/ansible/import_vars.yml"
    
    print_info "Generating Ansible variables from export..."
    
    cat > "$vars_file" << EOF
---
# Auto-generated from export: $(basename "$export_dir")
# Generated: $(date)

# Import settings
import_packages: true
import_services: true
import_nvidia: auto
install_whitesur_theme: true
install_developer_tools: true

# Package lists
packages_manual_file: "$export_dir/packages_manual.txt"
packages_snap_file: "$export_dir/packages_snap.txt"
packages_flatpak_file: "$export_dir/packages_flatpak.txt"

# Mount points (will be detected)
mount_points_file: "$export_dir/mount_points.txt"

# GPU type
gpu_type_file: "$export_dir/gpu_type.txt"

# Desktop environment
desktop_env_file: "$export_dir/desktop_environment.txt"

# Services
services_file: "$export_dir/services_enabled.txt"
EOF
    
    print_success "Variables generated: $vars_file"
}

# Smart package name transformation (Ubuntu → Fedora naming)
transform_package_name() {
    local pkg="$1"
    
    # Common transformations
    case "$pkg" in
        # Development libraries: -dev → -devel
        *-dev)
            echo "${pkg/-dev/-devel}"
            ;;
        # Python packages
        python3-*)
            # Try both python3- and python- versions
            echo "$pkg"
            echo "${pkg/python3-/python-}"
            ;;
        # System tools
        "build-essential")
            echo "gcc gcc-c++ make kernel-devel"
            return
            ;;
        "net-tools")
            echo "net-tools"
            return
            ;;
        "dnsutils")
            echo "bind-utils"
            return
            ;;
        "htop")
            echo "btop"
            return
            ;;
        # Web servers
        "apache2")
            echo "httpd"
            return
            ;;
        # Containers
        "docker.io")
            echo "docker"
            return
            ;;
        # Databases
        "redis-server")
            echo "redis"
            return
            ;;
        "postgresql-client")
            echo "postgresql"
            return
            ;;
        "mysql-client")
            echo "mysql"
            return
            ;;
        # Browsers
        "chromium-browser")
            echo "chromium"
            return
            ;;
        # Default: return as-is
        *)
            echo "$pkg"
            ;;
    esac
}

# Search for package in Fedora repos using dnf search
find_fedora_package() {
    local ubuntu_pkg="$1"
    
    # Strip version info and architecture
    local clean_name=$(echo "$ubuntu_pkg" | sed 's/:.*//' | cut -d'=' -f1 | cut -d':' -f1)
    
    # Get transformed names
    local candidates=$(transform_package_name "$clean_name")
    
    # Try each candidate
    for candidate in $candidates; do
        # First, try exact match with dnf info (fastest)
        if dnf info "$candidate" &>/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done
    
    # If no exact match, try dnf search (slower but more thorough)
    local search_result=$(dnf search --quiet "$clean_name" 2>/dev/null | \
                         grep -E "^[a-zA-Z0-9_+-]+\." | \
                         head -1 | \
                         awk '{print $1}' | \
                         sed 's/\..*//')
    
    if [ -n "$search_result" ]; then
        echo "$search_result"
        return 0
    fi
    
    # Not found
    return 1
}

# Map Ubuntu packages to Fedora
map_packages() {
    local export_dir="$1"
    local ubuntu_packages="$export_dir/packages_manual.txt"
    local fedora_packages="$export_dir/packages_fedora_mapped.txt"
    local failed_packages="$export_dir/packages_failed.txt"
    
    print_info "Mapping Ubuntu packages to Fedora equivalents..."
    print_info "This will use dnf search to find the best matches..."
    echo ""
    
    > "$fedora_packages"
    > "$failed_packages"
    
    local total=0
    local mapped=0
    local skipped=0
    local failed=0
    
    # Create progress indicator
    local pkg_count=$(grep -cv '^#\|^$' "$ubuntu_packages" 2>/dev/null || echo 0)
    local current=0
    
    while IFS= read -r pkg; do
        # Skip empty lines and comments
        [ -z "$pkg" ] || [[ "$pkg" =~ ^# ]] && continue
        
        ((total++))
        ((current++))
        
        # Show progress every 10 packages
        if [ $((current % 10)) -eq 0 ]; then
            print_info "  Progress: $current/$pkg_count packages processed..."
        fi
        
        # Skip kernel and certain system packages
        if [[ "$pkg" =~ ^linux- ]] || [[ "$pkg" =~ ^(grub|udev|systemd) ]]; then
            ((skipped++))
            continue
        fi
        
        # Try to find Fedora equivalent
        local fedora_pkg=$(find_fedora_package "$pkg")
        
        if [ $? -eq 0 ] && [ -n "$fedora_pkg" ]; then
            echo "$fedora_pkg" >> "$fedora_packages"
            ((mapped++))
            # Show some successful mappings
            [ $((current % 50)) -eq 0 ] && print_success "  ✓ $pkg → $fedora_pkg"
        else
            echo "$pkg" >> "$failed_packages"
            ((failed++))
        fi
    done < "$ubuntu_packages"
    
    echo ""
    print_success "Package mapping complete!"
    print_info "  Mapped: $mapped packages"
    print_info "  Skipped: $skipped packages (system/kernel)"
    [ $failed -gt 0 ] && print_warning "  Failed: $failed packages"
    
    if [ -s "$failed_packages" ]; then
        echo ""
        print_info "Failed packages saved to: $(basename "$failed_packages")"
        print_info "These are often Ubuntu-specific or renamed packages."
    fi
}

# Auto-detect disks for mount points
detect_disks() {
    print_info "Detecting available disks..."
    
    print_info "Current disk layout:"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    echo ""
    
    print_info "Available unmounted disks:"
    lsblk -nlo NAME,SIZE,FSTYPE | while read name size fstype; do
        if ! mountpoint -q "/dev/$name" 2>/dev/null; then
            echo "  /dev/$name ($size, $fstype)"
        fi
    done
}

# Run Ansible playbook
run_ansible_import() {
    local export_dir="$1"
    
    print_info "Running Ansible import playbook..."
    
    cd "$REPO_ROOT/ansible"
    
    sudo ansible-playbook \
        -i inventory.ini \
        -e "@import_vars.yml" \
        -e "export_dir=$export_dir" \
        playbook_import.yml
}

# Generate installation report
generate_report() {
    local export_dir="$1"
    local report_file="$export_dir/import_report.txt"
    
    print_info "Generating installation report..."
    
    {
        echo "═══════════════════════════════════════════════════════"
        echo "LinMigrator - Installation Report"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        echo "Date: $(date)"
        echo "Target: $(hostname)"
        echo "Export ID: $(basename "$export_dir")"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Packages"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Mapped packages: $(wc -l < "$export_dir/packages_fedora_mapped.txt" 2>/dev/null || echo 0)"
        echo "Failed to map: $(wc -l < "$export_dir/packages_failed.txt" 2>/dev/null || echo 0)"
        echo ""
        if [ -f "$export_dir/packages_failed.txt" ] && [ -s "$export_dir/packages_failed.txt" ]; then
            echo "Packages that could not be installed:"
            cat "$export_dir/packages_failed.txt" | head -20
            [ $(wc -l < "$export_dir/packages_failed.txt") -gt 20 ] && echo "... (see full list in packages_failed.txt)"
        fi
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "System Components"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        [ -f "$export_dir/gpu_type.txt" ] && echo "GPU: $(cat "$export_dir/gpu_type.txt")"
        [ -f "$export_dir/desktop_environment.txt" ] && echo "Desktop: $(cat "$export_dir/desktop_environment.txt")"
        echo ""
        echo "NVIDIA/CUDA: $(command -v nvidia-smi &>/dev/null && echo "Installed" || echo "Not installed")"
        echo "WhiteSur Theme: $([ -d /usr/share/themes/WhiteSur* ] && echo "Installed" || echo "Not installed")"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Mount Points"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        df -h | grep -E '(/home|/var)'
        echo ""
        echo "═══════════════════════════════════════════════════════"
    } > "$report_file"
    
    cat "$report_file"
    
    print_success "Report saved: $report_file"
}

# Main execution
main() {
    print_header
    
    check_os
    
    # Check for export ID argument
    EXPORT_ID="$1"
    
    if [ -z "$EXPORT_ID" ]; then
        list_exports
        read -p "Enter export number or ID: " selection
        
        # If number, get the export ID
        if [[ "$selection" =~ ^[0-9]+$ ]]; then
            EXPORT_ID=$(ls "$REPO_ROOT/exports"/*.tar.gz.enc 2>/dev/null | sed -n "${selection}p" | xargs basename | sed 's/.tar.gz.enc$//')
        else
            EXPORT_ID="$selection"
        fi
    fi
    
    print_info "Import ID: $EXPORT_ID"
    
    # Check for encryption key
    KEY_FILE="$HOME/.linmigrator_key"
    if [ ! -f "$KEY_FILE" ]; then
        print_warning "Encryption key not found at: $KEY_FILE"
        read -p "Enter path to encryption key: " KEY_PATH
        if [ -f "$KEY_PATH" ]; then
            cp "$KEY_PATH" "$KEY_FILE"
            chmod 600 "$KEY_FILE"
        else
            print_error "Key file not found: $KEY_PATH"
            exit 1
        fi
    fi
    
    echo ""
    
    # Decrypt export
    EXPORT_DIR=$(decrypt_export "$EXPORT_ID" "$KEY_FILE")
    
    echo ""
    print_info "Export contents:"
    ls -lh "$EXPORT_DIR"
    echo ""
    
    # Show README if exists
    if [ -f "$EXPORT_DIR/README.md" ]; then
        cat "$EXPORT_DIR/README.md"
        echo ""
    fi
    
    # Bootstrap Fedora
    bootstrap_fedora
    
    echo ""
    
    # Map packages
    map_packages "$EXPORT_DIR"
    
    echo ""
    
    # Detect disks
    detect_disks
    
    echo ""
    
    # Create Ansible structure
    create_ansible_inventory
    generate_ansible_vars "$EXPORT_DIR"
    
    echo ""
    print_info "Ready to import!"
    echo ""
    read -p "Continue with import? (y/N): " CONTINUE
    
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        print_info "Import cancelled. You can run it later with:"
        print_info "  cd $REPO_ROOT/ansible"
        print_info "  sudo ansible-playbook -i inventory.ini playbook_import.yml"
        exit 0
    fi
    
    # Run Ansible import
    # run_ansible_import "$EXPORT_DIR"
    
    # Generate report
    generate_report "$EXPORT_DIR"
    
    echo ""
    print_success "═══════════════════════════════════════════════════════"
    print_success "Import Complete!"
    print_success "═══════════════════════════════════════════════════════"
    echo ""
    print_info "Next steps:"
    echo "  1. Review import report above"
    echo "  2. Reboot system: sudo reboot"
    echo "  3. Verify mounts: df -h"
    echo "  4. Test NVIDIA: nvidia-smi"
    echo ""
    print_success "Done! 🎉"
}

main "$@"
