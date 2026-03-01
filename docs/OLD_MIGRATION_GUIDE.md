# Ubuntu to Fedora Migration Guide

## Overview

This guide will help you migrate from Ubuntu to Fedora while preserving your data stored on separate `/var` and `/home` virtual disks. The migration is automated using Ansible and includes:

- Package inventory and migration
- Developer tools installation
- NVIDIA drivers and CUDA toolkit
- WhiteSur GTK theme with GNOME extensions (macOS look)
- Safe mounting of existing `/var` and `/home` disks

## Prerequisites

- **Source System**: Ubuntu VM with separate virtual disks for `/var` and `/home`
- **Target System**: Fresh Fedora installation
- **Proxmox**: Both VMs managed in Proxmox
- SSH access to the target Fedora system
- Root/sudo access on both systems

## Safety Considerations

⚠️ **IMPORTANT**: This migration involves mounting existing filesystems. Follow these steps carefully:

1. **Backup Everything**: Before starting, ensure you have backups of critical data
2. **Snapshots**: Take VM snapshots in Proxmox before migration
3. **Test First**: If possible, test on a clone of your target VM
4. **User Data**: SSH keys in `/home` will be preserved, but ensure you have alternative access

## Migration Steps

### Step 1: Prepare the Source System (Ubuntu)

1. **Attach Ubuntu disks to Proxmox** (not to the Fedora VM yet):
   ```bash
   # In Proxmox, detach the /var and /home disks from Ubuntu VM
   # Note the disk identifiers (e.g., scsi1, scsi2)
   ```

2. **Mount the Ubuntu disks temporarily** on a system where you can run the inventory script:
   ```bash
   # Create mount points
   sudo mkdir -p /mnt/ubuntu-var /mnt/ubuntu-home
   
   # Mount the disks (adjust device names as needed)
   sudo mount /dev/sdX1 /mnt/ubuntu-var
   sudo mount /dev/sdY1 /mnt/ubuntu-home
   ```

3. **Run the inventory gathering script**:
   ```bash
   sudo python3 scripts/gather_inventory.py \
     --root-mount /mnt/ubuntu-var \
     --home-mount /mnt/ubuntu-home \
     --output inventory/ubuntu_system.json
   ```

4. **Unmount the disks**:
   ```bash
   sudo umount /mnt/ubuntu-var /mnt/ubuntu-home
   ```

### Step 2: Prepare the Target System (Fedora)

1. **Ensure fresh Fedora installation** with basic network configuration

2. **Note the following information**:
   - Target system IP address
   - Root or sudo user credentials
   - Device identifiers for the disks you'll attach

3. **Update the inventory file** (`inventory/hosts.ini`):
   ```ini
   [fedora_target]
   fedora-vm ansible_host=<TARGET_IP> ansible_user=<USERNAME>
   ```

4. **Configure disk mappings** in `group_vars/fedora_target.yml`:
   ```yaml
   var_disk_device: "/dev/sdb1"    # Adjust based on your setup
   home_disk_device: "/dev/sdc1"   # Adjust based on your setup
   ```

### Step 3: Bootstrap the Target System

From your control machine (can be your workstation):

1. **Install Ansible** (if not already installed):
   ```bash
   # On Ubuntu/Debian
   sudo apt update && sudo apt install ansible python3-pip
   
   # On Fedora
   sudo dnf install ansible python3-pip
   ```

2. **Test SSH connection**:
   ```bash
   ssh <USERNAME>@<TARGET_IP>
   ```

3. **Run the bootstrap script**:
   ```bash
   ./scripts/bootstrap_target.sh <TARGET_IP> <USERNAME>
   ```

   This will:
   - Install Ansible on the target
   - Install Python dependencies
   - Configure sudo access
   - Test the connection

### Step 4: Attach Disks in Proxmox

1. **In Proxmox web interface**:
   - Select your Fedora VM
   - Go to Hardware section
   - Click "Add" → "Hard Disk"
   - Select "Use existing disk"
   - Choose the `/var` disk from Ubuntu
   - Repeat for the `/home` disk

2. **Boot the Fedora VM** (don't mount the disks yet - Ansible will do this)

3. **Verify disks are visible**:
   ```bash
   ssh <USERNAME>@<TARGET_IP>
   lsblk
   # You should see your additional disks (e.g., sdb, sdc)
   ```

### Step 5: Run the Migration Playbook

⚠️ **Review the playbook** before running:
```bash
cat playbooks/migrate.yml
```

**Dry run first** (check mode):
```bash
ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --check
```

**Run the actual migration**:
```bash
ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
```

The playbook will:
1. ✅ Validate system state
2. ✅ Install base packages and equivalents from Ubuntu
3. ✅ Install developer tools (git, docker, VSCode, etc.)
4. ✅ Install NVIDIA drivers and CUDA
5. ✅ Mount `/var` and `/home` disks (with safety checks)
6. ✅ Install WhiteSur theme and GNOME extensions
7. ✅ Configure system settings
8. ✅ Validate the migration

### Step 6: Post-Migration Validation

1. **Reboot the system**:
   ```bash
   ssh <USERNAME>@<TARGET_IP> 'sudo reboot'
   ```

2. **Verify mounts after reboot**:
   ```bash
   ssh <USERNAME>@<TARGET_IP>
   df -h
   # Check that /var and /home are mounted
   ```

3. **Test SSH with your keys**:
   ```bash
   # Your SSH keys from /home should work now
   ssh -i ~/.ssh/id_rsa <USERNAME>@<TARGET_IP>
   ```

4. **Verify services**:
   ```bash
   systemctl status
   nvidia-smi  # Check NVIDIA drivers
   nvcc --version  # Check CUDA
   ```

5. **Test GNOME appearance**:
   - Log in to the GNOME desktop
   - Verify WhiteSur theme is applied
   - Check GNOME extensions are active

### Step 7: Cleanup

1. **Remove old Ubuntu VM** (after confirming everything works):
   - Take a final backup if needed
   - Delete the Ubuntu VM in Proxmox
   - Keep snapshots of Fedora VM for a while

2. **Remove temporary files**:
   ```bash
   rm -rf /mnt/ubuntu-* inventory/ubuntu_system.json
   ```

## Troubleshooting

### Issue: Disks won't mount

```bash
# Check filesystem
sudo fsck /dev/sdX1

# Check /etc/fstab on target
cat /etc/fstab

# Try manual mount
sudo mount /dev/sdX1 /var
```

### Issue: Package installation fails

```bash
# Check the package mapping
cat inventory/ubuntu_system.json

# Install manually
sudo dnf install <package-name>
```

### Issue: NVIDIA drivers not loading

```bash
# Check driver installation
rpm -qa | grep nvidia

# Rebuild initramfs
sudo dracut --force

# Check secure boot
mokutil --sb-state
```

### Issue: WhiteSur theme not applying

```bash
# Reinstall theme
cd /tmp
git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git
cd WhiteSur-gtk-theme
./install.sh

# Apply via GNOME Tweaks
gnome-tweaks
```

## Rollback Procedure

If something goes wrong:

1. **Restore Proxmox snapshot**:
   - Go to Proxmox → VM → Snapshots
   - Select the pre-migration snapshot
   - Click "Rollback"

2. **Reattach disks to Ubuntu**:
   - Detach from Fedora VM
   - Reattach to Ubuntu VM
   - Boot Ubuntu

3. **Investigate logs**:
   ```bash
   # On target system
   journalctl -xe
   cat /var/log/ansible.log
   ```

## Additional Resources

- [Fedora Documentation](https://docs.fedoraproject.org/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [WhiteSur Theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
- [NVIDIA CUDA on Fedora](https://rpmfusion.org/Howto/NVIDIA)

## Support

For issues specific to this migration tool, check the logs in:
- `logs/migration.log`
- `/var/log/ansible.log` (on target)

---

**Happy Migrating! 🚀**
