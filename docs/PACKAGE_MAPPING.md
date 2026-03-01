# Package Mapping Guide

How LinMigrator translates Ubuntu packages to Fedora equivalents.

## Overview

Ubuntu (Debian-based) and Fedora (RPM-based) use different package names and conventions. LinMigrator automatically translates package names using intelligent search and transformation rules.

## Mapping Process

### 1. Package Name Cleaning

```bash
# Input examples
python3-dev:amd64=3.10.6-1
build-essential=12.9ubuntu3

# After cleaning
python3-dev
build-essential
```

Removes:
- Architecture (`:amd64`, `:i386`)
- Version (`=3.10.6-1`)
- Revision numbers

### 2. Transformation Rules

Common naming pattern changes:

| Ubuntu Pattern | Fedora Pattern | Example |
|---------------|----------------|---------|
| `*-dev` | `*-devel` | `libssl-dev` → `openssl-devel` |
| `lib*-dev` | `lib*-devel` | `libcurl4-dev` → `libcurl-devel` |
| `python3-*` | `python3-*` or `python-*` | `python3-pip` → `python3-pip` |
| `*-client` | `*` | `mysql-client` → `mysql` |
| `*-server` | `*` or `*-server` | `redis-server` → `redis` |

### 3. Special Cases

Some packages have completely different names:

| Ubuntu | Fedora | Reason |
|--------|--------|--------|
| `build-essential` | `gcc gcc-c++ make kernel-devel` | Meta-package expansion |
| `apache2` | `httpd` | Different naming convention |
| `dnsutils` | `bind-utils` | Different package name |
| `net-tools` | `net-tools` | Same (lucky!) |
| `htop` | `btop` | Upgraded to modern alternative |
| `docker.io` | `docker` | Snap vs native |
| `chromium-browser` | `chromium` | Simplified name |

### 4. Search Algorithm

For each package, the script:

```bash
# 1. Try exact match
if dnf info "package-name" &>/dev/null; then
    echo "package-name"  # Found!
    
# 2. Try transformed name
elif dnf info "package-name-devel" &>/dev/null; then
    echo "package-name-devel"  # Found with -devel!
    
# 3. Search repos
else
    dnf search "package-name" | head -1
fi
```

### 5. Version Handling

**Key principle:** No version numbers!

```bash
# Ubuntu export contains
python3-pip=21.3.1

# Fedora install uses
dnf install python3-pip  # Gets latest version automatically
```

This ensures:
- ✅ Always get latest security updates
- ✅ Compatible with current Fedora release
- ✅ Proper dependency resolution
- ✅ No conflicts with repo versions

## Category-Specific Mappings

### Build Tools

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `build-essential` | `gcc gcc-c++ make kernel-devel` | Meta-package → Individual tools |
| `cmake` | `cmake` | Direct match |
| `autoconf` | `autoconf` | Direct match |
| `automake` | `automake` | Direct match |
| `pkg-config` | `pkg-config` | Direct match |

### Python Development

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `python3` | `python3` | Direct match |
| `python3-pip` | `python3-pip` | Direct match |
| `python3-dev` | `python3-devel` | -dev → -devel |
| `python3-venv` | `python3-virtualenv` | Different implementation |
| `libpython3-dev` | `python3-devel` | Included in python3-devel |
| `ipython` | `ipython` | Direct match |
| `python3-pytest` | `python3-pytest` | Direct match |

### Node.js & JavaScript

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `nodejs` | `nodejs` | Direct match |
| `npm` | `npm` | Direct match |
| `yarn` | `yarn` | Direct match |

### Containers

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `docker.io` | `docker` | Snap vs native |
| `docker-compose` | `docker-compose` | Direct match |
| `podman` | `podman` | Direct match |
| `buildah` | `buildah` | Direct match |

### Databases

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `postgresql` | `postgresql postgresql-server` | Need both |
| `postgresql-client` | `postgresql` | Client included |
| `mysql-server` | `mysql-server` | Direct match |
| `mysql-client` | `mysql` | Client included |
| `redis-server` | `redis` | Simpler name |
| `sqlite3` | `sqlite` | Simpler name |

### Database Development Libraries

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `libpq-dev` | `libpq-devel` | PostgreSQL dev |
| `libmysqlclient-dev` | `mysql-devel` | MySQL dev |
| `libsqlite3-dev` | `sqlite-devel` | SQLite dev |

### Web Servers

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `nginx` | `nginx` | Direct match |
| `apache2` | `httpd` | Different name! |
| `php` | `php` | Direct match |
| `php-fpm` | `php-fpm` | Direct match |

### Development Libraries

| Ubuntu | Fedora | Pattern |
|--------|--------|---------|
| `libssl-dev` | `openssl-devel` | lib*-dev → *-devel |
| `libcurl4-openssl-dev` | `libcurl-devel` | Simplified |
| `libxml2-dev` | `libxml2-devel` | -dev → -devel |
| `libxslt1-dev` | `libxslt-devel` | -dev → -devel |
| `zlib1g-dev` | `zlib-devel` | -dev → -devel |
| `libbz2-dev` | `bzip2-devel` | -dev → -devel |
| `libffi-dev` | `libffi-devel` | -dev → -devel |
| `libreadline-dev` | `readline-devel` | -dev → -devel |
| `libncurses5-dev` | `ncurses-devel` | -dev → -devel |

### System Tools

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `net-tools` | `net-tools` | Direct match |
| `dnsutils` | `bind-utils` | Different name |
| `htop` | `btop` | Upgraded to modern tool |
| `vim` | `vim-enhanced` | Enhanced version |
| `curl` | `curl` | Direct match |
| `wget` | `wget` | Direct match |

### Fonts

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `fonts-liberation` | `liberation-fonts` | Reversed name |
| `fonts-dejavu` | `dejavu-fonts` | Reversed name |
| `fonts-noto` | `google-noto-fonts` | Different prefix |

### GNOME Desktop

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `gnome-tweaks` | `gnome-tweaks` | Direct match |
| `gnome-shell-extensions` | `gnome-shell-extensions` | Direct match |
| `chrome-gnome-shell` | `chrome-gnome-shell` | Direct match |

### Applications

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `firefox` | `firefox` | Direct match |
| `chromium-browser` | `chromium` | Simpler name |
| `vlc` | `vlc` | Direct match (needs RPM Fusion) |
| `gimp` | `gimp` | Direct match |
| `inkscape` | `inkscape` | Direct match |
| `libreoffice` | `libreoffice` | Direct match |
| `code` | `code` | Direct match (VSCode) |

### Multimedia Libraries

| Ubuntu | Fedora | Notes |
|--------|--------|-------|
| `ffmpeg` | `ffmpeg` | Requires RPM Fusion |
| `libavcodec-dev` | `ffmpeg-devel` | Requires RPM Fusion |
| `libavformat-dev` | `ffmpeg-devel` | Included |

## Packages That Won't Map

### Ubuntu-Specific

These packages don't exist on Fedora:

- `ubuntu-desktop` - Ubuntu's desktop meta-package
- `ubuntu-*` - Any ubuntu-prefixed package
- `unity-*` - Ubuntu's Unity desktop
- `landscape-*` - Canonical's management tool
- `snapd` - Snap daemon (Fedora uses native packages)

### Kernel Packages

Automatically skipped:

- `linux-*` - Kernel packages (use Fedora's kernel)
- `linux-headers-*` - Kernel headers (use kernel-devel)
- `linux-image-*` - Kernel images

### Replaced/Obsolete

Some packages are obsolete or replaced:

- Old Python 2 packages → Use Python 3
- GTK 2 libraries → GTK 3/4
- Qt 4 packages → Qt 5/6

## Manual Intervention

### Reviewing Failed Packages

After import, check:

```bash
cat exports/your-export-id/packages_failed.txt
```

### Common Resolutions

**Package:** `python-dev` (Python 2)  
**Solution:** Not needed, Python 2 is EOL

**Package:** `libpng12-dev`  
**Solution:** Use `libpng-devel` (newer version)

**Package:** `mysql-workbench`  
**Solution:** Install from Flathub: `flatpak install mysql-workbench`

**Package:** `spotify-client`  
**Solution:** Install from Flathub: `flatpak install spotify`

### Manual Installation

For packages that failed to map:

```bash
# Search Fedora repos
dnf search package-name

# Search RPM Fusion
dnf search --enablerepo=rpmfusion-free package-name

# Try Flatpak
flatpak search package-name

# Install manually
sudo dnf install correct-fedora-name
```

## RPM Fusion Requirement

Some packages require RPM Fusion repositories:

**Multimedia:**
- `ffmpeg` - Video/audio codecs
- `vlc` - Media player
- `HandBrake` - Video transcoder

**NVIDIA:**
- NVIDIA drivers (handled automatically)
- CUDA toolkit

LinMigrator enables RPM Fusion automatically during bootstrap.

## Success Rate

Typical mapping success rates:

- **80-90%**: Development tools, CLI utilities
- **70-80%**: Desktop applications
- **60-70%**: System libraries
- **50-60%**: Multimedia packages
- **~0%**: Ubuntu-specific packages

Overall average: **75-85%** successful mappings

## Improving Mapping

### Add Transformations

Edit `scripts/import.sh`:

```bash
transform_package_name() {
    case "$pkg" in
        # Add your custom mappings
        "my-ubuntu-pkg")
            echo "my-fedora-pkg"
            return
            ;;
```

### Report Issues

If you find a common package that should map but doesn't:

1. Open GitHub issue
2. Provide Ubuntu package name
3. Provide correct Fedora equivalent
4. We'll add it to transformations

## Best Practices

1. **Review failed packages** - They're often not needed
2. **Use Flatpak** - For packages not in Fedora repos
3. **Check alternatives** - Fedora might have a better equivalent
4. **Test your app** - Even if packages failed, app might work
5. **Report patterns** - Help improve the mapper

## Next Steps

- [Import Guide](IMPORT_GUIDE.md) - Full import process
- [Troubleshooting](TROUBLESHOOTING.md) - Solving package issues
- [Flatpak Guide](FLATPAK_GUIDE.md) - Installing Flatpak apps
