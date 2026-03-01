# Export Guide

Comprehensive guide to the export process and customization options.

## Overview

The export script (`scripts/export.sh`) scans your Ubuntu system and creates an encrypted snapshot of your configuration. This snapshot can be stored in Git and later imported to Fedora.

## What Gets Exported

### Automatically Detected:

1. **Mount Points**
   - All non-system mounts (excludes tmpfs, proc, sys, dev, etc.)
   - Device paths, mount points, filesystem types
   - UUIDs for reliable disk identification

2. **Packages**
   - APT packages (all + manually installed)
   - Snap packages
   - Flatpak packages
   - Package names only (versions determined at import time)

3. **Services**
   - Enabled systemd services
   - Service names only (not configuration)

4. **Users & Groups**
   - Regular users (UID ≥ 1000)
   - User groups
   - *Note:* Passwords are NOT exported for security

5. **Hardware**
   - GPU type (NVIDIA, AMD, Intel, or unknown)
   - GPU model information

6. **Desktop Environment**
   - Detected DE (GNOME, KDE, XFCE, etc.)
   - Used to determine theme installation

7. **System Information**
   - Hostname, kernel version, architecture
   - Memory, CPU info
   - Disk usage

## Usage

### Basic Export

```bash
sudo ./scripts/export.sh
```

### What Happens Step-by-Step

1. **Pre-flight checks**
   - Verifies Ubuntu OS
   - Checks for required tools (openssl, tar, git)

2. **Key generation/verification**
   - Creates `~/.linmigrator_key` if it doesn't exist
   - Or uses existing key if present
   - Key is AES-256 compatible

3. **System scanning**
   - Detects mount points → `mount_points.txt`
   - Scans APT packages → `packages_apt.txt`, `packages_manual.txt`
   - Scans Snap packages → `packages_snap.txt`
   - Scans Flatpak packages → `packages_flatpak.txt`
   - Lists services → `services_enabled.txt`
   - Collects users → `users.txt`, `groups.txt`
   - Detects GPU → `gpu_type.txt`, `gpu_info.txt`
   - Identifies desktop → `desktop_environment.txt`
   - Gathers system info → `system_info.txt`

4. **Configuration creation**
   - Generates `export.conf` (human-readable!)
   - Sets default import flags
   - Lists mount points with import=true/false

5. **Encryption**
   - Creates tar.gz archive
   - Encrypts with OpenSSL AES-256-CBC + PBKDF2
   - Saves as `hostname_timestamp.tar.gz.enc`
   - Deletes unencrypted files

6. **Git commit** (optional)
   - Adds encrypted export to repo
   - Commits with descriptive message
   - Pushes to origin/main

## Export Structure

After decryption, an export contains:

```
hostname_20260301_123456/
├── README.md                    # Export documentation
├── export.conf                  # Main config (EDITABLE!)
├── packages_apt.txt             # All APT packages
├── packages_manual.txt          # Manually installed packages
├── packages_snap.txt            # Snap packages
├── packages_flatpak.txt         # Flatpak packages
├── mount_points.txt             # Detected mount points
├── services_enabled.txt         # Enabled services
├── users.txt                    # User list
├── groups.txt                   # Group list
├── gpu_type.txt                 # GPU type (nvidia/amd/intel)
├── gpu_info.txt                 # Detailed GPU info
├── desktop_environment.txt      # Desktop name
└── system_info.txt              # System details
```

## Customizing Export Configuration

After export (or after decryption on Fedora), you can edit `export.conf`:

```ini
# LinMigrator Export Configuration
[metadata]
version=1.0.0
export_date=2026-03-01
source_hostname=ubuntu-vm

[import_settings]
import_packages=true           # Install packages?
import_services=true           # Enable services?
import_users=false             # Usually leave false
import_nvidia=auto             # auto, true, or false
import_whitesur_theme=true     # Install macOS-like theme?
import_developer_tools=true    # Install dev tools?

[mount_points]
# Format: device|mountpoint|fstype|import
/dev/sdb1|/var|ext4|true      # Import this disk
/dev/sdc1|/home|ext4|true     # Import this disk
/dev/sdd1|/data|ext4|false    # Skip this disk
```

### Import Settings Explained

- **import_packages**: Install all detected packages
- **import_services**: Enable services that were enabled on Ubuntu
- **import_users**: Create users from Ubuntu (usually not needed)
- **import_nvidia**: `auto` detects from GPU, `true` forces install, `false` skips
- **import_whitesur_theme**: Install WhiteSur GTK theme (macOS-like)
- **import_developer_tools**: Install dev tools (Git, Docker, VSCode, Python, etc.)

### Mount Points Configuration

Set `import=false` for any disk you don't want to mount:

```ini
/dev/sdd1|/data|ext4|false    # Won't be mounted on import
```

## Customizing Package Lists

You can edit package files before encryption (or after decryption):

```bash
# Edit to remove unwanted packages
nano exports/your-export/packages_manual.txt

# Comment out packages you don't want
# firefox        ← This won't be installed
chromium        ← This will be installed
# vim            ← This won't be installed
```

## Encryption Key Management

### Key Location
```bash
~/.linmigrator_key
```

### Backup Your Key

**CRITICAL:** Without this key, you cannot decrypt exports!

```bash
# Copy to USB drive
cp ~/.linmigrator_key /media/usb/

# Copy to another machine
scp ~/.linmigrator_key user@backup-host:~/

# Print for paper backup (use with caution!)
cat ~/.linmigrator_key
```

### GitHub Secrets (Optional)

Store your key in GitHub for CI/CD or team access:

1. Go to repository → Settings → Secrets and variables → Actions
2. New repository secret: `LINMIGRATOR_KEY`
3. Paste content: `cat ~/.linmigrator_key`

## Advanced Options

### Skip Encryption (Not Recommended)

If you want unencrypted exports (e.g., for testing):

```bash
# Modify export.sh to skip encrypt_export() call
# Then manually commit the directory
```

### Multiple Exports

You can create multiple exports:

```bash
sudo ./scripts/export.sh  # Creates export 1
# Make some changes to system
sudo ./scripts/export.sh  # Creates export 2
```

Each gets a unique timestamp ID.

### Re-importing Old Exports

Old exports remain valid. You can import them anytime:

```bash
sudo ./scripts/import.sh ubuntu-vm_20260201_100000
```

## Export Size

Typical export sizes:

- **Small system** (~100 packages): 50-100 KB
- **Medium system** (~500 packages): 100-200 KB  
- **Large system** (1000+ packages): 200-500 KB

Exports are tiny because they only contain package names and configuration, not the packages themselves.

## Troubleshooting

### "No mount points found"

**Cause:** No non-system mounts detected

**Solution:** This is normal if you don't have separate `/var` or `/home` disks. The import will just skip disk mounting.

### "Encryption failed"

**Cause:** OpenSSL not installed

**Solution:**
```bash
sudo apt install openssl
```

### "Git push failed"

**Cause:** No Git credentials or remote not set

**Solution:**
```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git remote -v  # Verify remote is set
```

## Security Considerations

### What's Encrypted
- All export files (packages, mounts, config, etc.)
- Stored safely in Git

### What's NOT Encrypted
- The encryption key itself (`~/.linmigrator_key`)
- Must be stored separately

### What's NOT Exported
- User passwords
- SSH private keys
- Browser passwords/cookies
- Application data
- File contents

## Best Practices

1. **Export regularly** - Keep exports updated with system changes
2. **Test exports** - Verify you can decrypt before you need them
3. **Multiple backups of key** - USB drive, cloud storage, paper
4. **Version control** - Keep old exports for rollback capability
5. **Document changes** - Git commit messages describe the export
6. **Clean old exports** - Remove very old exports to save space

## Next Steps

- [Import Guide](IMPORT_GUIDE.md) - How to use exports on Fedora
- [Package Mapping](PACKAGE_MAPPING.md) - How packages are translated
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
