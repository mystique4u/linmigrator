#!/bin/bash
# Local setup script for running migration on Fedora itself
# Use this when you only have the Fedora machine running

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║       LinMigrator - Local Setup (Single Machine)          ║
║       Ubuntu → Fedora Migration                           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "This script will set up Ansible for local execution on this Fedora machine"
echo ""

# Check if running on Fedora
if [ ! -f /etc/fedora-release ]; then
    print_error "This doesn't appear to be a Fedora system!"
    print_info "Current OS: $(cat /etc/os-release | grep PRETTY_NAME)"
    exit 1
fi

print_success "Running on Fedora $(cat /etc/fedora-release)"

# Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    print_info "Installing Ansible..."
    sudo dnf install -y ansible python3-pip python3-dnf libselinux-python3
    print_success "Ansible installed"
else
    print_success "Ansible already installed: $(ansible --version | head -1)"
fi

# Install additional Python packages
print_info "Installing Python dependencies..."
pip3 install --user jmespath 2>/dev/null || true

# Create logs directory
mkdir -p logs
print_success "Logs directory created"

# Update inventory for local execution
print_info "Configuring inventory for local execution..."
cat > inventory/hosts.ini << 'EOF'
[fedora_target]
localhost ansible_connection=local

[fedora_target:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
print_success "Inventory configured for localhost"

# Test Ansible connection
print_info "Testing Ansible connectivity..."
if ansible -i inventory/hosts.ini fedora_target -m ping; then
    print_success "Ansible connection test passed!"
else
    print_error "Ansible connection test failed"
    exit 1
fi

# Prompt for disk configuration
echo ""
print_info "Disk Configuration"
echo "────────────────────────────────────────────────────────"
echo ""
print_warning "Before continuing, ensure you have:"
print_warning "1. Attached the Ubuntu /var and /home disks to this machine in Proxmox"
print_warning "2. Booted up and can see the disks with: lsblk"
echo ""

read -p "Have you attached the Ubuntu disks? (y/n): " DISKS_READY
if [ "$DISKS_READY" != "y" ] && [ "$DISKS_READY" != "Y" ]; then
    echo ""
    print_warning "Please attach the disks in Proxmox first:"
    echo "  1. In Proxmox, select this VM"
    echo "  2. Hardware → Add → Hard Disk → Use existing disk"
    echo "  3. Attach both /var and /home disks from Ubuntu"
    echo "  4. Reboot this VM"
    echo "  5. Run this script again"
    exit 0
fi

# Show current disks
echo ""
print_info "Current disk layout:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

echo ""
read -p "Enter /var disk device (e.g., /dev/sdb1): " VAR_DISK
read -p "Enter /home disk device (e.g., /dev/sdc1): " HOME_DISK

# Verify disks exist
if [ ! -b "$VAR_DISK" ]; then
    print_error "Disk $VAR_DISK not found!"
    exit 1
fi

if [ ! -b "$HOME_DISK" ]; then
    print_error "Disk $HOME_DISK not found!"
    exit 1
fi

print_success "Both disks found"

# Update group_vars
print_info "Updating disk configuration..."
sed -i "s|var_disk_device:.*|var_disk_device: \"${VAR_DISK}\"|" group_vars/fedora_target.yml
sed -i "s|home_disk_device:.*|home_disk_device: \"${HOME_DISK}\"|" group_vars/fedora_target.yml
print_success "Disk configuration updated"

# Check if inventory file exists
echo ""
if [ ! -f "inventory/ubuntu_system.json" ]; then
    print_warning "Ubuntu inventory not found!"
    echo ""
    print_info "You need to gather the inventory from the Ubuntu disks first."
    echo ""
    read -p "Do you want to mount the disks and gather inventory now? (y/n): " GATHER_NOW
    
    if [ "$GATHER_NOW" = "y" ] || [ "$GATHER_NOW" = "Y" ]; then
        print_info "Creating temporary mount points..."
        sudo mkdir -p /mnt/ubuntu-var /mnt/ubuntu-home
        
        print_info "Mounting Ubuntu disks..."
        sudo mount "$VAR_DISK" /mnt/ubuntu-var
        sudo mount "$HOME_DISK" /mnt/ubuntu-home
        
        print_success "Disks mounted"
        
        print_info "Gathering inventory (this may take a minute)..."
        sudo python3 scripts/gather_inventory.py \
            --root-mount /mnt/ubuntu-var \
            --home-mount /mnt/ubuntu-home \
            --output inventory/ubuntu_system.json
        
        print_success "Inventory gathered"
        
        print_info "Unmounting disks..."
        sudo umount /mnt/ubuntu-var
        sudo umount /mnt/ubuntu-home
        
        print_success "Disks unmounted"
    else
        print_warning "Skipping inventory gathering. You'll need to do this manually:"
        echo "  sudo mkdir -p /mnt/ubuntu-var /mnt/ubuntu-home"
        echo "  sudo mount $VAR_DISK /mnt/ubuntu-var"
        echo "  sudo mount $HOME_DISK /mnt/ubuntu-home"
        echo "  sudo python3 scripts/gather_inventory.py \\"
        echo "    --root-mount /mnt/ubuntu-var \\"
        echo "    --home-mount /mnt/ubuntu-home \\"
        echo "    --output inventory/ubuntu_system.json"
        echo "  sudo umount /mnt/ubuntu-var /mnt/ubuntu-home"
        exit 0
    fi
fi

# Final summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Local Setup Complete!                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration:"
echo "  ✓ Ansible installed and configured"
echo "  ✓ Inventory set to localhost"
echo "  ✓ /var disk: $VAR_DISK"
echo "  ✓ /home disk: $HOME_DISK"
echo "  ✓ Ubuntu inventory: $([ -f inventory/ubuntu_system.json ] && echo 'Ready' || echo 'Not found')"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Review configuration:"
echo "   ${BLUE}vim group_vars/fedora_target.yml${NC}"
echo ""
echo "2. Run a dry-run first (recommended):"
echo "   ${BLUE}ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --check${NC}"
echo ""
echo "3. Run the actual migration:"
echo "   ${BLUE}sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml${NC}"
echo ""
echo "   ${RED}Note: Use 'sudo' since we're mounting disks and modifying system files${NC}"
echo ""
echo "4. After migration, reboot:"
echo "   ${BLUE}sudo reboot${NC}"
echo ""
print_success "Ready to migrate! 🚀"
