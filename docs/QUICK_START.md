# Quick Start Guide

Get up and running with LinMigrator in minutes!

## Prerequisites

- **Source System:** Ubuntu with separate `/var` and `/home` disks
- **Target System:** Fresh Fedora installation
- **Tools:** Git, OpenSSL (installed automatically)

## Step 1: Export from Ubuntu

```bash
# Clone the repository
git clone https://github.com/mystique4u/linmigrator.git
cd linmigrator

# Run export script (requires sudo)
sudo ./scripts/export.sh
```

**What happens:**
- Scans all mount points (auto-detects `/var`, `/home`, etc.)
- Collects installed packages from APT, Snap, Flatpak
- Detects GPU type (NVIDIA, AMD, Intel)
- Identifies desktop environment
- Collects enabled services
- Encrypts everything with AES-256
- Pushes to Git repository

**Important:** Save your encryption key!
```bash
# Backup the key
cp ~/.linmigrator_key ~/backup/
```

## Step 2: Import to Fedora

```bash
# Clone the repository on Fedora
git clone https://github.com/mystique4u/linmigrator.git
cd linmigrator

# Copy your encryption key
scp user@ubuntu-host:~/.linmigrator_key ~/

# Run import script (requires sudo)
sudo ./scripts/import.sh
```

**What happens:**
- Lists available encrypted exports
- Decrypts selected export
- Bootstraps Fedora (installs Ansible, Python, tools)
- Maps Ubuntu packages to Fedora equivalents using `dnf search`
- Detects available disks for mounting
- Installs all packages (fetches latest versions)
- Configures system
- Generates installation report

## Step 3: Reboot & Verify

```bash
# Reboot to load new drivers and mounts
sudo reboot

# After reboot, verify everything
df -h                    # Check mounts
nvidia-smi              # Check GPU (if NVIDIA)
dnf list installed      # Check packages
```

## Optional: Use Quick Start Helper

```bash
# Interactive guide
./scripts/quick_start.sh
```

This script detects your OS and guides you through the appropriate workflow.

## Next Steps

- Read [Migration Guide](MIGRATION_GUIDE.md) for detailed information
- Check [Troubleshooting](TROUBLESHOOTING.md) if you encounter issues
- See [Export Guide](EXPORT_GUIDE.md) for export customization
- See [Import Guide](IMPORT_GUIDE.md) for import options

## Common Scenarios

### Scenario 1: Simple Home Lab Migration

```bash
# Ubuntu
sudo ./scripts/export.sh

# Fedora
sudo ./scripts/import.sh
# Select export, press Enter, done!
```

### Scenario 2: Proxmox VM Migration

```bash
# 1. On Ubuntu VM: Export
sudo ./scripts/export.sh

# 2. In Proxmox: 
#    - Shutdown Ubuntu VM
#    - Detach /var and /home disks
#    - Attach disks to Fedora VM

# 3. On Fedora VM: Import
sudo ./scripts/import.sh
# Disks will be auto-detected and mounted
```

### Scenario 3: Selective Migration

```bash
# Ubuntu: Export
sudo ./scripts/export.sh

# Fedora: Before importing, edit the export config
cd exports/your-export-id/
nano export.conf
# Change import flags: import_nvidia=false, etc.

# Then import
sudo ../scripts/import.sh
```

## Time Estimates

- **Export:** 2-5 minutes (depends on package count)
- **Encryption:** 1-2 minutes
- **Decryption:** 1-2 minutes
- **Bootstrap:** 3-5 minutes (installing Ansible)
- **Package mapping:** 5-10 minutes (depends on package count)
- **Installation:** 15-30 minutes (depends on packages and internet speed)
- **Total:** ~30-60 minutes for full migration

## Tips

1. **Backup your key!** Without it, you can't decrypt exports
2. **Edit export.conf** before importing to customize what gets installed
3. **Check the report** after import to see what succeeded/failed
4. **Don't skip the reboot** - drivers and mounts need it
5. **Keep exports** - You can re-import or import to multiple machines

## Need Help?

- Check logs in `/var/log/migration/`
- Review import report: `exports/your-id/import_report.txt`
- See [Troubleshooting Guide](TROUBLESHOOTING.md)
- Open an issue on GitHub
