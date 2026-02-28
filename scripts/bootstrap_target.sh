#!/bin/bash
# Bootstrap script for Fedora target system
# Installs Ansible and prepares the system for migration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_HOST="${1:-}"
TARGET_USER="${2:-root}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Bootstrap Fedora Target System

Usage: $0 <target_host> [target_user]

Arguments:
    target_host     IP address or hostname of the Fedora target system
    target_user     SSH user (default: root)

Examples:
    $0 192.168.1.100
    $0 fedora-vm.local myuser
    $0 10.0.0.5 admin

This script will:
    1. Test SSH connectivity
    2. Install Ansible on the target
    3. Install Python dependencies
    4. Configure sudo access (if needed)
    5. Test Ansible connectivity

Prerequisites:
    - SSH access to the target system
    - Target system has internet connectivity
    - Fresh Fedora installation
EOF
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if SSH is available
    if ! command -v ssh &> /dev/null; then
        print_error "SSH client not found. Please install OpenSSH client."
        exit 1
    fi
    
    # Check if we have the target host
    if [ -z "$TARGET_HOST" ]; then
        print_error "Target host not specified"
        echo ""
        show_usage
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

test_ssh_connectivity() {
    print_info "Testing SSH connectivity to ${TARGET_USER}@${TARGET_HOST}..."
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "${TARGET_USER}@${TARGET_HOST}" "echo 'SSH connection successful'" 2>/dev/null; then
        print_success "SSH connection successful"
        return 0
    else
        print_warning "SSH key-based authentication failed, you may need to enter password"
        
        # Try with password
        if ssh -o ConnectTimeout=5 "${TARGET_USER}@${TARGET_HOST}" "echo 'SSH connection successful'"; then
            print_success "SSH connection successful (with password)"
            print_info "Consider setting up SSH key authentication for better automation"
            return 0
        else
            print_error "Cannot connect to ${TARGET_USER}@${TARGET_HOST}"
            print_info "Please check:"
            print_info "  - Target host is reachable (ping ${TARGET_HOST})"
            print_info "  - SSH service is running on target"
            print_info "  - Username and credentials are correct"
            print_info "  - Firewall allows SSH connections"
            exit 1
        fi
    fi
}

install_ansible_on_target() {
    print_info "Installing Ansible and dependencies on target system..."
    
    ssh "${TARGET_USER}@${TARGET_HOST}" 'bash -s' << 'ENDSSH'
set -e

echo "[INFO] Updating system packages..."
sudo dnf update -y --quiet

echo "[INFO] Installing Ansible and Python dependencies..."
sudo dnf install -y ansible python3-pip python3-dnf libselinux-python3

echo "[INFO] Verifying Ansible installation..."
ansible --version

echo "[INFO] Installing additional Python packages..."
pip3 install --user jmespath

echo "[SUCCESS] Ansible installation complete"
ENDSSH
    
    if [ $? -eq 0 ]; then
        print_success "Ansible installed successfully on target"
    else
        print_error "Failed to install Ansible on target"
        exit 1
    fi
}

configure_sudo() {
    print_info "Checking sudo configuration..."
    
    if [ "$TARGET_USER" != "root" ]; then
        print_info "Configuring passwordless sudo for ${TARGET_USER}..."
        
        ssh "${TARGET_USER}@${TARGET_HOST}" "bash -s" << ENDSSH
if sudo -n true 2>/dev/null; then
    echo "[INFO] User already has passwordless sudo"
else
    echo "[INFO] Configuring passwordless sudo..."
    echo "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${TARGET_USER}
    sudo chmod 0440 /etc/sudoers.d/${TARGET_USER}
    echo "[SUCCESS] Passwordless sudo configured"
fi
ENDSSH
        
        print_success "Sudo configuration complete"
    else
        print_info "Running as root, sudo configuration not needed"
    fi
}

test_ansible_connection() {
    print_info "Testing Ansible connection..."
    
    # Temporarily update inventory
    TEMP_INVENTORY=$(mktemp)
    cat > "$TEMP_INVENTORY" << EOF
[fedora_target]
bootstrap-test ansible_host=${TARGET_HOST} ansible_user=${TARGET_USER}

[fedora_target:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
    
    if ansible -i "$TEMP_INVENTORY" fedora_target -m ping; then
        print_success "Ansible connection test passed"
        rm -f "$TEMP_INVENTORY"
        return 0
    else
        print_error "Ansible connection test failed"
        rm -f "$TEMP_INVENTORY"
        exit 1
    fi
}

create_log_directory() {
    print_info "Creating log directory..."
    
    mkdir -p "${PROJECT_ROOT}/logs"
    print_success "Log directory created"
}

show_next_steps() {
    cat << EOF

${GREEN}╔══════════════════════════════════════════════════════════════╗
║            Bootstrap Complete!                                ║
╚══════════════════════════════════════════════════════════════╝${NC}

Next steps:

1. Update the inventory file:
   ${YELLOW}vim inventory/hosts.ini${NC}
   
   Add your host:
   fedora-vm ansible_host=${TARGET_HOST} ansible_user=${TARGET_USER}

2. Update disk configuration:
   ${YELLOW}vim group_vars/fedora_target.yml${NC}
   
   Configure:
   - var_disk_device: "/dev/sdb1"  # Your /var disk
   - home_disk_device: "/dev/sdc1" # Your /home disk

3. Attach Ubuntu disks in Proxmox:
   - Select Fedora VM in Proxmox
   - Hardware → Add → Hard Disk → Use existing disk
   - Attach both /var and /home disks from Ubuntu

4. Gather inventory from Ubuntu disks (mount them first):
   ${YELLOW}sudo python3 scripts/gather_inventory.py \\
     --root-mount /mnt/ubuntu-var \\
     --home-mount /mnt/ubuntu-home \\
     --output inventory/ubuntu_system.json${NC}

5. Run the migration playbook:
   ${YELLOW}ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml${NC}

${BLUE}For detailed instructions, see: MIGRATION_GUIDE.md${NC}

EOF
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║           Fedora Target Bootstrap Script                  ║
║           Ubuntu → Fedora Migration                       ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    check_prerequisites
    test_ssh_connectivity
    install_ansible_on_target
    configure_sudo
    create_log_directory
    test_ansible_connection
    show_next_steps
    
    print_success "Bootstrap completed successfully! 🎉"
}

# Run main function
main
