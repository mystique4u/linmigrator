#!/bin/bash
# LinMigrator v2.0 - Quick Start Guide

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          LinMigrator v2.0 - Quick Start                   ║
║          Ubuntu → Fedora Migration                        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Welcome to LinMigrator! This guide will help you get started.${NC}"
echo ""

# Detect current OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    CURRENT_OS=$ID
else
    CURRENT_OS="unknown"
fi

echo -e "${BLUE}Detected OS: ${YELLOW}$CURRENT_OS${NC}"
echo ""

# Check which phase we're in
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Migration Workflow:${NC}"
echo ""
echo -e "  1️⃣  Export from Ubuntu (source system)"
echo -e "  2️⃣  Push encrypted export to Git"
echo -e "  3️⃣  Clone repo on Fedora (target system)"
echo -e "  4️⃣  Import to Fedora"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Provide guidance based on OS
if [[ "$CURRENT_OS" == "ubuntu" ]] || [[ "$CURRENT_OS" == "debian" ]]; then
    echo -e "${GREEN}✓ You're on Ubuntu/Debian (source system)${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    echo -e "1. Run the export script:"
    echo -e "   ${BLUE}sudo ./scripts/export.sh${NC}"
    echo ""
    echo -e "2. This will:"
    echo -e "   - Auto-detect mount points (/var, /home, etc.)"
    echo -e "   - Scan installed packages (APT, Snap, Flatpak)"
    echo -e "   - Detect GPU and desktop environment"
    echo -e "   - Create encrypted export"
    echo -e "   - Store in exports/ directory"
    echo ""
    echo -e "3. Backup your encryption key:"
    echo -e "   ${BLUE}cp ~/.linmigrator_key /safe/location/${NC}"
    echo ""
    echo -e "4. Push to Git (export.sh does this automatically)"
    echo ""
    echo -e "5. On your Fedora system:"
    echo -e "   - Clone this repo"
    echo -e "   - Copy encryption key to ~/.linmigrator_key"
    echo -e "   - Run: ${BLUE}sudo ./scripts/import.sh${NC}"
    echo ""
    
    # Ask if they want to run export now
    echo ""
    read -p "Would you like to run the export script now? [y/N]: " RUN_EXPORT
    if [[ "$RUN_EXPORT" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}Starting export...${NC}"
        echo ""
        exec sudo ./scripts/export.sh
    else
        echo ""
        echo -e "${YELLOW}Run when ready: ${BLUE}sudo ./scripts/export.sh${NC}"
    fi

elif [[ "$CURRENT_OS" == "fedora" ]] || [[ "$CURRENT_OS" == "rhel" ]] || [[ "$CURRENT_OS" == "centos" ]]; then
    echo -e "${GREEN}✓ You're on Fedora/RHEL (target system)${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo ""
    echo -e "1. Make sure you have your encryption key:"
    echo -e "   ${BLUE}~/.linmigrator_key${NC}"
    echo ""
    echo -e "   If not, copy it from Ubuntu:"
    echo -e "   ${BLUE}scp user@ubuntu-host:~/.linmigrator_key ~/${NC}"
    echo ""
    echo -e "2. Run the import script:"
    echo -e "   ${BLUE}sudo ./scripts/import.sh${NC}"
    echo ""
    echo -e "3. This will:"
    echo -e "   - Show available exports"
    echo -e "   - Decrypt selected export"
    echo -e "   - Bootstrap Fedora (install Ansible, Python, etc.)"
    echo -e "   - Map Ubuntu packages to Fedora"
    echo -e "   - Install everything"
    echo -e "   - Configure system"
    echo -e "   - Generate installation report"
    echo ""
    
    # Check if key exists
    if [ -f ~/.linmigrator_key ]; then
        echo -e "${GREEN}✓ Encryption key found at ~/.linmigrator_key${NC}"
    else
        echo -e "${RED}⚠️  Encryption key NOT found at ~/.linmigrator_key${NC}"
        echo -e "${YELLOW}   Please copy it from your Ubuntu system first.${NC}"
        echo ""
        exit 1
    fi
    
    # Check if exports exist
    if [ -d "./exports" ] && [ "$(ls -A ./exports/*.enc 2>/dev/null)" ]; then
        echo -e "${GREEN}✓ Encrypted exports found in ./exports/${NC}"
    else
        echo -e "${YELLOW}⚠️  No encrypted exports found in ./exports/${NC}"
        echo -e "${YELLOW}   Make sure you've pulled the latest from Git.${NC}"
        echo ""
    fi
    
    # Ask if they want to run import now
    echo ""
    read -p "Would you like to run the import script now? [y/N]: " RUN_IMPORT
    if [[ "$RUN_IMPORT" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${GREEN}Starting import...${NC}"
        echo ""
        exec sudo ./scripts/import.sh
    else
        echo ""
        echo -e "${YELLOW}Run when ready: ${BLUE}sudo ./scripts/import.sh${NC}"
    fi

else
    echo -e "${YELLOW}⚠️  Unsupported OS: $CURRENT_OS${NC}"
    echo ""
    echo -e "LinMigrator supports:"
    echo -e "  - ${GREEN}Ubuntu/Debian${NC} as source (export)"
    echo -e "  - ${GREEN}Fedora/RHEL${NC} as target (import)"
    echo ""
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Documentation:${NC}"
echo ""
echo -e "  📖 Full guide: ${BLUE}cat README.md${NC}"
echo -e "  🔐 Encryption: Check ~/.linmigrator_key"
echo -e "  📦 Exports: Check ./exports/"
echo -e "  🎯 Ansible: All files in ./ansible/"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""
