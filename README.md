# LinMigrator - Smart Ubuntu to Fedora Migration

**Intelligent system migration with auto-detection, encryption, and zero hardcoded values.**

## 🎯 What's New (v2.0)

- ✅ **Auto-detection** - Automatically scans mount points, packages, GPU, desktop
- ✅ **No hardcoded values** - Everything detected dynamically
- ✅ **Encryption** - Exports are encrypted before storing in Git
- ✅ **Two-script workflow** - Export from source, import to target
- ✅ **Editable exports** - Human-readable config files
- ✅ **Smart package mapping** - Ubuntu → Fedora with fallback detection
- ✅ **Installation reports** - See what worked and what didn't
- ✅ **btop instead of htop** - Modern system monitor

## 🚀 Quick Start

### On Ubuntu (Source System):

```bash
# 1. Clone repository
git clone https://github.com/mystique4u/linmigrator.git
cd linmigrator

# 2. Export your system
./scripts/export.sh
```

This will:
- Scan all mount points (auto-detects /var, /home, etc.)
- Collect installed packages from APT, Snap, Flatpak
- Detect GPU, desktop environment, services
- Create encrypted export
- Push to repository

**Save your encryption key!** `~/.linmigrator_key`

### On Fedora (Target System):

```bash
# 1. Clone repository
git clone https://github.com/mystique4u/linmigrator.git
cd linmigrator

# 2. Copy your encryption key
scp user@source:~/.linmigrator_key ~/

# 3. Run import
./scripts/import.sh

# 4. Select your export and follow prompts
```

This will:
- Decrypt your export
- Bootstrap Fedora (install Ansible, Python, etc.)
- Map Ubuntu packages to Fedora
- Install everything
- Configure system
- Generate report

## 📁 Project Structure

```
linmigrator/
├── scripts/
│   ├── export.sh          # Export from Ubuntu (auto-detection)
│   └── import.sh          # Import to Fedora (bootstrap + install)
├── exports/
│   └── hostname_timestamp.tar.gz.enc  # Your encrypted exports
├── ansible/
│   ├── playbook_import.yml           # Smart import playbook
│   ├── roles/
│   │   ├── mount_disks_dynamic/     # Auto-mount from export
│   │   ├── packages/                 # Package installation
│   │   ├── developer_tools/          # Dev tools (uses btop!)
│   │   ├── nvidia_cuda/              # NVIDIA/CUDA
│   │   ├── whitesur_theme/           # macOS-like theme
│   │   └── system_config/            # System configuration
│   └── inventory.ini                 # Auto-generated
└── docs/
    └── [various guides]
```

## ✨ Features

### Export Script (`export.sh`)

**Auto-detects:**
- ✅ Mount points (excluding system/temporary)
- ✅ APT packages (all + manually installed)
- ✅ Snap packages
- ✅ Flatpak packages
- ✅ Enabled systemd services
- ✅ Users and groups (UID ≥ 1000)
- ✅ GPU type (NVIDIA, AMD, Intel)
- ✅ Desktop environment (GNOME, KDE, etc.)
- ✅ System information

**Creates:**
- Encrypted archive (AES-256)
- Human-readable configuration
- Editable package lists
- Mount point mappings

### Import Script (`import.sh`)

**Automatically:**
- ✅ Bootstraps Fedora (Ansible, Python, tools)
- ✅ Decrypts export
- ✅ Maps packages Ubuntu → Fedora
- ✅ Detects available disks
- ✅ Mounts disks based on export config
- ✅ Installs packages (with fallback)
- ✅ Configures NVIDIA if detected
- ✅ Installs WhiteSur theme
- ✅ Sets up developer tools
- ✅ Generates installation report

## 🔐 Encryption

Exports are encrypted with OpenSSL AES-256-CBC:

```bash
# Key location
~/.linmigrator_key

# Backup your key!
cp ~/.linmigrator_key /safe/location/

# Optional: Add to GitHub Secrets
# Settings → Secrets → New secret: LINMIGRATOR_KEY
```

## 📝 Export Configuration

After export, you get an editable `export.conf`:

```ini
# LinMigrator Export Configuration
[metadata]
version=1.0.0
export_date=2026-03-01
source_hostname=ubuntu-vm

[import_settings]
import_packages=true
import_services=true
import_users=false
import_nvidia=auto
import_whitesur_theme=true
import_developer_tools=true

[mount_points]
# Format: device|mountpoint|fstype|import
/dev/sdb1|/var|ext4|true
/dev/sdc1|/home|ext4|true
/dev/sdd1|/data|ext4|false  # ← Set to false to skip
```

**Edit before importing to customize what gets migrated!**

## 🎨 What Gets Installed

### Base System
- Mapped packages from Ubuntu
- System services
- Developer tools (Git, Docker, VSCode, Python, Node.js, etc.)
- Modern CLI tools (btop, ripgrep, fzf, etc.)

### Graphics
- NVIDIA drivers (if NVIDIA GPU detected)
- CUDA toolkit
- GPU persistence mode

### Desktop
- WhiteSur GTK theme (macOS-like)
- WhiteSur icons and cursors
- GNOME extensions
- Dock configuration

## 📊 Installation Report

After import, you get a detailed report:

```
═══════════════════════════════════════════
LinMigrator - Installation Report
═══════════════════════════════════════════

Packages
  Mapped: 245
  Failed: 12

Failed packages:
  - some-ubuntu-specific-package
  - another-unavailable-package

System Components
  GPU: nvidia
  Desktop: GNOME
  NVIDIA/CUDA: Installed
  WhiteSur Theme: Installed

Mount Points
  /var: 50G (mounted from /dev/sdb1)
  /home: 100G (mounted from /dev/sdc1)
═══════════════════════════════════════════
```

## 🔧 Advanced Usage

### Custom Export Options

```bash
# Export without encryption (not recommended)
./scripts/export.sh --no-encrypt

# Export with custom key file
./scripts/export.sh --key /path/to/key

# Specify what to export
./scripts/export.sh --no-packages --services-only
```

### Custom Import Options

```bash
# Skip certain components
./scripts/import.sh --skip-nvidia --skip-theme

# Use specific export
./scripts/import.sh --export exports/myhost_20260301.tar.gz.enc

# Dry run (show what would be done)
./scripts/import.sh --dry-run
```

### Manual Package Mapping

Edit `exports/your-export/packages_ubuntu.txt` before importing:

```bash
# Add comments to skip packages
# firefox  ← Will be skipped
chromium
# vim  ← Will be skipped
```

Or edit the mapped list in `exports/your-export/packages_fedora.txt`:

```bash
# Change package names
firefox → librewolf
chromium → chromium-freeworld
```

## 🎮 NVIDIA/CUDA Setup

**Automatically detected and installed when NVIDIA GPU is found.**

What gets installed:
- NVIDIA drivers (latest from RPM Fusion)
- CUDA toolkit
- nvidia-settings
- GPU persistence daemon

Manual installation:
```bash
cd ansible
ansible-playbook -i localhost, -c local playbook_import.yml --tags nvidia
```

## 🎨 WhiteSur Theme Setup

**macOS Big Sur-like theme for GNOME.**

Includes:
- WhiteSur GTK theme (light/dark)
- WhiteSur icon theme
- WhiteSur cursor theme
- Dash to Dock configuration
- macOS-like system settings

Manual installation:
```bash
cd ansible
ansible-playbook -i localhost, -c local playbook_import.yml --tags whitesur_theme
```

## 💾 Disk Management

### How Disks Are Detected

Export script:
1. Scans all mounted filesystems
2. Excludes system mounts (tmpfs, proc, sys, dev, run, boot)
3. Identifies persistent disks with UUIDs
4. Stores mount points and filesystem types

Import script:
1. Reads mount configuration from export
2. Uses `lsblk` to find available disks
3. Matches by UUID/LABEL when possible
4. Prompts for disk selection if multiple matches
5. Backs up existing content
6. Mounts and updates `/etc/fstab`

### Manual Disk Configuration

Edit `exports/your-export/mount_points.txt`:

```
# Format: device|mountpoint|fstype|uuid|label|import
/dev/sdb1|/var|ext4|abc-123|VARDATA|true
/dev/sdc1|/home|ext4|def-456|HOMEDATA|true
/dev/sdd1|/data|ext4|ghi-789|EXTRADATA|false  ← Skip this
```

Change `import` from `true` to `false` to skip mounting a disk.

## 🐛 Troubleshooting

### Export Issues

**Problem:** "No mount points found"
- **Solution:** Check that you have non-system mounts. Run `mount | grep -v 'tmpfs\|proc\|sys\|dev'`

**Problem:** "Encryption failed"
- **Solution:** Ensure OpenSSL is installed: `sudo apt install openssl`

### Import Issues

**Problem:** "Decryption failed"
- **Solution:** Verify key file matches: `diff ~/.linmigrator_key /path/from/source`

**Problem:** "Package not found"
- **Solution:** Normal! Some Ubuntu packages don't exist on Fedora. Check the report for alternatives.

**Problem:** "Disk not found"
- **Solution:** Ensure disk is attached in Proxmox before running import. Run `lsblk` to verify.

**Problem:** "NVIDIA installation failed"
- **Solution:** Enable RPM Fusion repos manually:
  ```bash
  sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  ```

### Permission Issues

All operations require sudo/root:
```bash
sudo ./scripts/export.sh
sudo ./scripts/import.sh
```

## 📚 Documentation

- **[Export Script Details](docs/EXPORT_GUIDE.md)** - How auto-detection works
- **[Import Script Details](docs/IMPORT_GUIDE.md)** - Bootstrap and installation process
- **[Package Mapping](docs/PACKAGE_MAPPING.md)** - Ubuntu → Fedora package equivalents
- **[Encryption Guide](docs/ENCRYPTION_GUIDE.md)** - Key management and security

## 🤝 Contributing

Improvements welcome! Areas to contribute:

- Package mapping additions (Ubuntu → Fedora)
- Support for other distributions
- Additional desktop environment support
- Better GPU detection (AMD, Intel)
- Automated testing

## 📜 License

MIT License - See LICENSE file

## 🎯 Use Case: Proxmox VM Migration

This tool was designed for Proxmox environments where:

1. **Source:** Ubuntu VM with separate virtual disks for `/var` and `/home`
2. **Target:** Fresh Fedora VM
3. **Process:**
   - Detach `/var` and `/home` disks from Ubuntu VM
   - Attach disks to Fedora VM
   - Run export on Ubuntu (before shutdown) or use old export
   - Run import on Fedora
   - System configured identically to Ubuntu with Fedora packages

**Result:** Seamless migration preserving data, configurations, and workflow.

## 🆚 Old vs New Approach

### Old Approach (v1.x)
- ❌ Hardcoded disk paths
- ❌ Manual package list editing
- ❌ Required remote Ansible setup
- ❌ IP configuration needed
- ❌ Complex inventory gathering

### New Approach (v2.0)
- ✅ Auto-detect everything
- ✅ Two simple scripts
- ✅ Local execution (no network)
- ✅ Encrypted exports
- ✅ Editable configuration
- ✅ Smart package mapping
- ✅ Installation reports

## 🙏 Credits

- **WhiteSur Theme:** [vinceliuice/WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
- **btop:** [aristocratos/btop](https://github.com/aristocratos/btop)
- **Ansible:** Configuration management by Red Hat

---

**Made with ❤️ for smooth Ubuntu → Fedora migrations**

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
