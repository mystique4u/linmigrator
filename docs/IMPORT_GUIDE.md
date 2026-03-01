# Import Guide

Comprehensive guide to the import process on Fedora.

## Overview

The import script (`scripts/import.sh`) takes an encrypted export from Ubuntu and applies it to a Fedora system. It handles package mapping, disk mounting, and system configuration automatically.

## Prerequisites

- Fresh Fedora installation
- Network connection (for package downloads)
- Encryption key from Ubuntu export (`~/.linmigrator_key`)
- Sufficient disk space (10GB+ recommended)

## Basic Import

```bash
# Clone repository
git clone https://github.com/mystique4u/linmigrator.git
cd linmigrator

# Copy encryption key
scp user@ubuntu:~/.linmigrator_key ~/

# Run import
sudo ./scripts/import.sh
```

## What Happens Step-by-Step

### 1. Pre-flight Checks
- Verifies Fedora OS
- Checks for required tools
- Lists available exports

### 2. Export Selection
```
Available exports:
  1) ubuntu-vm_20260301_120000 (245 KB)
  2) ubuntu-vm_20260215_100000 (238 KB)

Enter export number or ID: 1
```

### 3. Decryption
- Validates encryption key
- Decrypts export archive
- Extracts to `exports/export-id/`
- Shows export contents

### 4. Bootstrap Fedora
Installs essential tools:
- Python 3 and pip
- Ansible
- Git, wget, curl
- OpenSSL, tar, gzip
- DNF plugins

### 5. Package Mapping
Smart package translation:
```
Mapping Ubuntu packages to Fedora equivalents...
  Progress: 10/245 packages processed...
  Progress: 20/245 packages processed...
  ...
  ✓ python3-dev → python3-devel
  ✓ apache2 → httpd
  ✓ build-essential → gcc gcc-c++ make
```

**How it works:**
1. Clean package name (remove version)
2. Apply common transformations
   - `-dev` → `-devel`
   - `python3-` → can try `python-` too
   - `apache2` → `httpd`
3. Try exact match with `dnf info`
4. Fall back to `dnf search`
5. Build install list

### 6. Disk Detection
```
Detecting available disks...
Current disk layout:
NAME   SIZE  TYPE FSTYPE MOUNTPOINT
sda    50G   disk ext4   /
sdb    100G  disk ext4   
sdc    200G  disk ext4   
```

Shows unmounted disks available for mounting.

### 7. Ansible Preparation
- Creates inventory: `ansible/inventory.ini`
- Generates variables: `ansible/import_vars.yml`
- Points to export directory

### 8. Confirmation
```
Ready to import!

Continue with import? (y/N):
```

### 9. Package Installation
Installs packages using DNF:
- Uses latest versions from Fedora repos
- Like running `dnf install package-name`
- No version numbers specified
- Handles dependencies automatically

### 10. System Configuration
- Mounts disks from export config
- Installs NVIDIA drivers (if GPU detected)
- Installs WhiteSur theme (if enabled)
- Installs developer tools (if enabled)
- Configures services

### 11. Report Generation
```
═══════════════════════════════════════════════════════
LinMigrator - Installation Report
═══════════════════════════════════════════════════════

Packages
  Mapped: 235 packages
  Failed: 10 packages

System Components
  GPU: nvidia
  Desktop: GNOME
  NVIDIA/CUDA: Installed
  WhiteSur Theme: Installed

Mount Points
  /var: 100G (mounted from /dev/sdb1)
  /home: 200G (mounted from /dev/sdc1)
```

## Customization Options

### Edit Export Config Before Import

```bash
# After decryption, before "Continue with import"
# Open another terminal
cd exports/your-export-id/
nano export.conf

# Modify settings
import_nvidia=false           # Skip NVIDIA
import_whitesur_theme=false   # Skip theme
import_developer_tools=false  # Skip dev tools

# Save and return to import
```

### Selective Package Installation

Edit package lists:
```bash
cd exports/your-export-id/
nano packages_manual.txt

# Comment out packages you don't want
# firefox
chromium
# gimp
```

### Custom Mount Points

Edit mount configuration:
```bash
nano exports/your-export-id/export.conf

# Change import flags
/dev/sdb1|/var|ext4|true     # Mount this
/dev/sdc1|/home|ext4|false   # Skip this
```

## Import Settings

### Packages (`import_packages=true`)
- Installs all mapped packages
- Uses `dnf install package-name`
- Fetches latest versions automatically
- Handles dependencies

### Services (`import_services=true`)
- Enables services that were enabled on Ubuntu
- Doesn't start them (waits for reboot)
- Ignores Ubuntu-specific services

### NVIDIA (`import_nvidia=auto`)
- **auto**: Installs if NVIDIA GPU detected
- **true**: Forces installation
- **false**: Skips NVIDIA drivers

Installs:
- NVIDIA proprietary drivers
- CUDA toolkit
- nvidia-settings
- Configures persistence mode

### WhiteSur Theme (`import_whitesur_theme=true`)
macOS-like theme for GNOME:
- GTK theme
- Icon theme
- Cursor theme
- GNOME Shell extensions
- Dock configuration

### Developer Tools (`import_developer_tools=true`)
Comprehensive dev environment:
- Git, GitHub CLI
- Docker, Podman
- VSCode
- Python (pip, virtualenv, development tools)
- Node.js, npm, yarn
- Build tools (gcc, make, cmake)
- Database clients (PostgreSQL, MySQL, Redis)
- Modern CLI tools (btop, ripgrep, fzf, jq)
- Rust, Go, Java toolchains

## Package Mapping Details

### Transformation Rules

The import script applies these transformations:

```bash
# Development libraries
*-dev          → *-devel
lib*-dev       → lib*-devel

# Python packages
python3-*      → python3-* or python-*

# System tools
build-essential → gcc gcc-c++ make kernel-devel
net-tools       → net-tools
dnsutils        → bind-utils
htop            → btop

# Web servers
apache2         → httpd
nginx           → nginx

# Containers
docker.io       → docker
docker-compose  → docker-compose

# Databases
redis-server    → redis
postgresql-client → postgresql
mysql-client    → mysql

# Browsers
chromium-browser → chromium
firefox         → firefox
```

### Search Algorithm

For each package:

1. **Clean name**: Remove version, architecture
   - `package:amd64=1.2.3` → `package`

2. **Transform**: Apply naming rules
   - `python3-dev` → `python3-devel`

3. **Try exact match**: `dnf info package-name`
   - Fast, checks if package exists

4. **Search repos**: `dnf search package-name`
   - Finds similar packages
   - Returns best match

5. **Record result**:
   - Success → Add to install list
   - Failure → Add to failed list

### Failed Packages

Some packages can't be mapped:

- **Ubuntu-specific**: `ubuntu-desktop`, `unity-*`
- **Renamed completely**: Different names on Fedora
- **Not available**: Package doesn't exist in Fedora repos
- **Obsolete**: Package replaced by something else

Check `packages_failed.txt` after mapping.

## Disk Mounting

### Auto-Detection

Import script shows available disks:
```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

### Mount Process

For each mount point in export config with `import=true`:

1. **Parse entry**: `device|mountpoint|fstype|import`
2. **Resolve UUID/LABEL**: Convert to device path
3. **Check existence**: Verify disk is attached
4. **Backup existing**: Save current content if any
5. **Mount**: Add to `/etc/fstab` and mount
6. **SELinux**: Restore contexts

### Manual Disk Selection

If auto-detection fails, you'll be prompted:

```
Mount /var from:
  1) /dev/sdb1 (100G, ext4)
  2) /dev/sdc1 (200G, ext4)
  3) Skip

Select disk: 1
```

## Post-Import Tasks

### Reboot Required

```bash
sudo reboot
```

Required for:
- NVIDIA drivers to load
- Kernel modules to initialize
- Services to start properly

### Verification Checklist

```bash
# Check mounts
df -h
mountpoint /var
mountpoint /home

# Check NVIDIA (if installed)
nvidia-smi
nvcc --version

# Check packages
dnf list installed | grep -i python
dnf list installed | grep -i docker

# Check services
systemctl status docker
systemctl status firewalld

# Check theme (GNOME)
gsettings get org.gnome.desktop.interface gtk-theme
```

### Review Report

```bash
cat exports/your-export-id/import_report.txt
```

Shows:
- Packages installed vs failed
- System components status
- Mount point information
- Recommendations

## Troubleshooting

### Import Script Won't Run

**Error:** "This script must run on Fedora!"

**Solution:** You're on Ubuntu. Run export.sh instead, or switch to Fedora system.

---

**Error:** "Encryption key not found"

**Solution:**
```bash
# Copy key from Ubuntu
scp user@ubuntu:~/.linmigrator_key ~/

# Or specify path when prompted
```

### Package Installation Failures

**Error:** Many packages in `packages_failed.txt`

**Solution:** This is normal! Ubuntu packages that don't exist on Fedora:
- Ubuntu-specific packages (ubuntu-desktop)
- Renamed packages (check Fedora equivalent)
- Obsolete packages

Review the report and manually install if needed.

---

**Error:** "Transaction failed: conflicting packages"

**Solution:** Some packages conflict. The import continues despite this. Check report for details.

### Disk Mounting Issues

**Error:** "Device not found"

**Solution:** Disk not attached in Proxmox:
1. Shutdown Fedora VM
2. Attach disks in Proxmox (Hardware → Add → Hard Disk)
3. Boot Fedora VM
4. Re-run import

---

**Error:** "Disk already mounted"

**Solution:**
```bash
# Unmount first
sudo umount /var
sudo umount /home

# Re-run import
sudo ./scripts/import.sh
```

### NVIDIA Installation Issues

**Error:** "NVIDIA driver not loading"

**Solution:**
```bash
# Check Secure Boot
mokutil --sb-state

# If enabled, disable Secure Boot in BIOS
# Or sign the kernel module (advanced)

# Rebuild kernel modules
sudo akmods --force
sudo dracut --force

# Reboot
sudo reboot
```

### Bootstrap Failures

**Error:** "dnf update failed"

**Solution:** Network or repo issues:
```bash
# Check network
ping -c 3 google.com

# Check repos
sudo dnf repolist

# Update repos
sudo dnf clean all
sudo dnf makecache
```

## Advanced Usage

### Dry Run

To see what would be installed without installing:

1. Run import until "Continue with import?"
2. Answer **No**
3. Review generated files in `ansible/`
4. Check `exports/your-id/packages_fedora_mapped.txt`

### Manual Ansible Run

If you want more control:

```bash
cd ansible
sudo ansible-playbook \
  -i inventory.ini \
  -e "@import_vars.yml" \
  -e "export_dir=/path/to/export" \
  playbook_import.yml \
  --tags "packages"  # Only install packages
```

Available tags:
- `packages` - Package installation only
- `nvidia` - NVIDIA/CUDA only
- `whitesur_theme` - Theme only
- `mount` - Disk mounting only

### Multiple Imports

You can import the same export to multiple Fedora systems:

```bash
# System 1
sudo ./scripts/import.sh ubuntu-vm_20260301_120000

# System 2 (different machine)
sudo ./scripts/import.sh ubuntu-vm_20260301_120000
```

Same export, multiple targets!

### Re-import After Failed Import

If import fails midway:

```bash
# Export is already decrypted in exports/
# Just re-run import with same export ID
sudo ./scripts/import.sh
```

## Best Practices

1. **Start with fresh Fedora** - Cleanest import experience
2. **Review export.conf first** - Customize before installing
3. **Check disk layout** - Verify disks attached in Proxmox
4. **Keep network fast** - Faster package downloads
5. **Don't interrupt** - Let it complete (can take 30+ min)
6. **Read the report** - Shows what worked and what didn't
7. **Reboot after import** - Required for drivers and services

## Next Steps

- [Troubleshooting Guide](TROUBLESHOOTING.md) - Detailed problem solving
- [Package Mapping](PACKAGE_MAPPING.md) - Understanding package translation
- [Configuration Guide](CONFIGURATION.md) - Advanced customization
