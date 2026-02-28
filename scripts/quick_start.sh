#!/bin/bash
# Quick start script for migration setup

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          LinMigrator - Ubuntu to Fedora                   ║
║          Quick Start Setup                                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}This script will help you set up the migration environment.${NC}"
echo ""

# Check if running from project root
if [ ! -f "ansible.cfg" ]; then
    echo -e "${YELLOW}⚠️  Please run this script from the project root directory${NC}"
    exit 1
fi

# Step 1: Configuration
echo -e "${BLUE}Step 1: Configuration${NC}"
echo "--------------------------------------"

read -p "Enter Fedora target IP address: " TARGET_IP
read -p "Enter SSH username [root]: " TARGET_USER
TARGET_USER=${TARGET_USER:-root}

read -p "Enter /var disk device [/dev/sdb1]: " VAR_DISK
VAR_DISK=${VAR_DISK:-/dev/sdb1}

read -p "Enter /home disk device [/dev/sdc1]: " HOME_DISK
HOME_DISK=${HOME_DISK:-/dev/sdc1}

# Update inventory
echo ""
echo -e "${BLUE}Updating inventory file...${NC}"
cat > inventory/hosts.ini << EOF
[fedora_target]
fedora-vm ansible_host=${TARGET_IP} ansible_user=${TARGET_USER}

[fedora_target:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo -e "${GREEN}✓ Inventory file updated${NC}"

# Update disk configuration
echo ""
echo -e "${BLUE}Updating disk configuration...${NC}"
sed -i "s|var_disk_device:.*|var_disk_device: \"${VAR_DISK}\"|" group_vars/fedora_target.yml
sed -i "s|home_disk_device:.*|home_disk_device: \"${HOME_DISK}\"|" group_vars/fedora_target.yml

echo -e "${GREEN}✓ Disk configuration updated${NC}"

# Step 2: Bootstrap
echo ""
echo -e "${BLUE}Step 2: Bootstrap Target System${NC}"
echo "--------------------------------------"
read -p "Do you want to bootstrap the target system now? (y/n): " BOOTSTRAP

if [ "$BOOTSTRAP" = "y" ] || [ "$BOOTSTRAP" = "Y" ]; then
    ./scripts/bootstrap_target.sh ${TARGET_IP} ${TARGET_USER}
else
    echo -e "${YELLOW}Skipping bootstrap. Run manually:${NC}"
    echo "  ./scripts/bootstrap_target.sh ${TARGET_IP} ${TARGET_USER}"
fi

# Step 3: Next steps
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete!                                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. ${YELLOW}Mount Ubuntu disks and gather inventory:${NC}"
echo "   sudo mount /dev/sdX1 /mnt/ubuntu-var"
echo "   sudo mount /dev/sdY1 /mnt/ubuntu-home"
echo "   sudo python3 scripts/gather_inventory.py \\"
echo "     --root-mount /mnt/ubuntu-var \\"
echo "     --home-mount /mnt/ubuntu-home \\"
echo "     --output inventory/ubuntu_system.json"
echo ""
echo "2. ${YELLOW}Attach Ubuntu disks in Proxmox to Fedora VM${NC}"
echo "   - Hardware → Add → Hard Disk → Use existing disk"
echo "   - Attach ${VAR_DISK} and ${HOME_DISK}"
echo ""
echo "3. ${YELLOW}Run the migration:${NC}"
echo "   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml"
echo ""
echo "4. ${YELLOW}For detailed instructions, see:${NC}"
echo "   cat MIGRATION_GUIDE.md"
echo ""
