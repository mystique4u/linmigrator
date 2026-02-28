# LinMigrator - Ubuntu to Fedora Migration Tool

Automated migration from Ubuntu to Fedora using Ansible, with support for preserving separate `/var` and `/home` virtual disks.

## Features

- 📦 **Package Migration**: Automatically maps Ubuntu packages to Fedora equivalents
- 🛠️ **Developer Tools**: Installs comprehensive development environment
- 🎨 **WhiteSur Theme**: macOS-like appearance with GNOME extensions
- 🎮 **NVIDIA & CUDA**: Latest drivers and CUDA toolkit installation
- 💾 **Safe Disk Mounting**: Validates and mounts existing `/var` and `/home` disks
- 🤖 **Fully Automated**: Ansible playbooks for repeatable migrations

## Quick Start

### Option 1: Local Execution (Single Machine - RECOMMENDED)

**Use this if only one machine is running at a time:**

1. **On Fedora, run the local setup:**
   ```bash
   ./scripts/local_setup.sh
   ```

2. **Follow the [Local Migration Guide](LOCAL_MIGRATION_GUIDE.md)** for detailed steps

3. **Run the migration on Fedora itself:**
   ```bash
   sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
   ```

### Option 2: Remote Execution (Control Machine)

**Use this if running Ansible from a separate control machine:**

1. **Read the [Migration Guide](MIGRATION_GUIDE.md)** for detailed instructions

2. **Gather inventory from Ubuntu system:**
   ```bash
   sudo python3 scripts/gather_inventory.py \
     --root-mount /mnt/ubuntu-var \
     --home-mount /mnt/ubuntu-home \
     --output inventory/ubuntu_system.json
   ```

3. **Bootstrap the Fedora target:**
   ```bash
   ./scripts/bootstrap_target.sh <TARGET_IP> <USERNAME>
   ```

4. **Run the migration:**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
   ```

## Project Structure

```
linmigrator/
├── MIGRATION_GUIDE.md          # Comprehensive migration instructions
├── README.md                   # This file
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   ├── hosts.ini              # Target system inventory
│   └── ubuntu_system.json     # Generated package inventory
├── group_vars/
│   └── fedora_target.yml      # Configuration variables
├── scripts/
│   ├── gather_inventory.py    # Ubuntu system inventory script
│   └── bootstrap_target.sh    # Target system bootstrap script
├── playbooks/
│   └── migrate.yml            # Main migration playbook
└── roles/
    ├── packages/              # Package installation
    ├── developer_tools/       # Dev tools setup
    ├── nvidia_cuda/           # NVIDIA & CUDA installation
    ├── whitesur_theme/        # WhiteSur theme setup
    ├── mount_disks/           # Disk mounting & validation
    └── system_config/         # System configuration
```

## Requirements

- **For Local Execution (Recommended):**
  - Fresh Fedora installation where you'll run the migration
  - Python 3.6+
  - Ansible will be installed by the setup script
  
- **For Remote Execution:**
  - Control Machine: Linux/macOS with Ansible 2.9+ and Python 3.6+
  - Target System: Fresh Fedora installation with network access

- **Both Scenarios:**
  - Source System: Ubuntu with separate `/var` and `/home` disks
  - Proxmox: VM management platform

## Safety Features

- ✅ Dry-run mode (check before apply)
- ✅ Disk validation before mounting
- ✅ Backup recommendations
- ✅ Rollback procedures
- ✅ Pre-flight system checks

## What Gets Migrated

- ✅ Installed packages (mapped to Fedora equivalents)
- ✅ System services configuration
- ✅ User data in `/home` (preserved on disk)
- ✅ Application data in `/var` (preserved on disk)
- ✅ Developer environment setup
- ✅ NVIDIA/CUDA configuration

## What Doesn't Get Migrated

- ❌ System-specific configurations (kernel modules, etc.)
- ❌ Ubuntu-specific PPAs (will be mapped to Fedora repos)
- ❌ Absolute file paths in configs (may need manual adjustment)

## Contributing

This is a personal migration tool, but feel free to adapt it for your needs:

1. Fork the repository
2. Modify the roles to fit your requirements
3. Test thoroughly before production use
4. Create snapshots before running

## License

MIT License - Use at your own risk. Always backup your data.

## Documentation

- 🏠 **[LOCAL_MIGRATION_GUIDE.md](LOCAL_MIGRATION_GUIDE.md)** - **For single machine setup (RECOMMENDED)**
- 📖 **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - For remote execution from control machine
- ✅ **[MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)** - Complete checklist for the migration process
- 🔧 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- 📋 **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - Detailed project overview and features

## Support

For troubleshooting, check:
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- `logs/ansible.log` - Ansible execution log
- `/var/log/migration/` - Migration logs on target system
- `journalctl -xe` - System logs on target

---

**⚠️ Important**: This tool modifies system configurations and mounts existing disks. Always test on non-production systems first and maintain backups.
