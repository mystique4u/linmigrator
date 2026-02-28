# Troubleshooting Guide

Common issues and solutions for the Ubuntu to Fedora migration.

## Table of Contents

1. [Connection Issues](#connection-issues)
2. [Disk Mounting Issues](#disk-mounting-issues)
3. [Package Installation Issues](#package-installation-issues)
4. [NVIDIA/CUDA Issues](#nvidiacuda-issues)
5. [Theme Issues](#theme-issues)
6. [Service Issues](#service-issues)
7. [Permission Issues](#permission-issues)
8. [General Issues](#general-issues)

---

## Connection Issues

### Problem: Cannot SSH to target system

**Symptoms:**
```
ssh: connect to host 192.168.1.100 port 22: Connection refused
```

**Solutions:**

1. **Verify target is reachable:**
   ```bash
   ping 192.168.1.100
   ```

2. **Check SSH service is running:**
   ```bash
   ssh user@fedora-ip "systemctl status sshd"
   ```

3. **Check firewall:**
   ```bash
   ssh user@fedora-ip "sudo firewall-cmd --list-all"
   # Add SSH if needed:
   sudo firewall-cmd --permanent --add-service=ssh
   sudo firewall-cmd --reload
   ```

4. **Verify correct IP address:**
   ```bash
   ip addr show
   ```

### Problem: Ansible ping fails

**Symptoms:**
```
fedora-vm | UNREACHABLE! => {"changed": false, "msg": "Failed to connect"}
```

**Solutions:**

1. **Test manual SSH first:**
   ```bash
   ssh -v user@target-ip
   ```

2. **Check inventory file:**
   ```bash
   cat inventory/hosts.ini
   # Verify ansible_host and ansible_user
   ```

3. **Test with explicit credentials:**
   ```bash
   ansible -i inventory/hosts.ini fedora_target -m ping -u root --ask-pass
   ```

4. **Check Python on target:**
   ```bash
   ssh user@target-ip "which python3"
   ```

---

## Disk Mounting Issues

### Problem: Disk device not found

**Symptoms:**
```
FAILED! => {"msg": "Disk /dev/sdb1 not found!"}
```

**Solutions:**

1. **Check available disks:**
   ```bash
   ssh user@fedora-ip "lsblk"
   ```

2. **Verify disks attached in Proxmox:**
   - Proxmox UI → Select VM → Hardware
   - Ensure disks are attached
   - Note the correct device names

3. **Update group_vars:**
   ```bash
   vim group_vars/fedora_target.yml
   # Update var_disk_device and home_disk_device
   ```

4. **Check disk is visible:**
   ```bash
   ssh user@fedora-ip "sudo fdisk -l"
   ```

### Problem: Disk already mounted

**Symptoms:**
```
mount: /var: /dev/sdb1 already mounted on /var
```

**Solutions:**

1. **Check current mounts:**
   ```bash
   ssh user@fedora-ip "mount | grep -E '(/var|/home)'"
   ```

2. **Unmount if needed:**
   ```bash
   ssh user@fedora-ip "sudo umount /var"
   ssh user@fedora-ip "sudo umount /home"
   ```

3. **Re-run playbook:**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --tags mount
   ```

### Problem: Filesystem corruption

**Symptoms:**
```
mount: wrong fs type, bad option, bad superblock
```

**Solutions:**

1. **Check filesystem:**
   ```bash
   ssh user@fedora-ip "sudo fsck -n /dev/sdb1"
   ```

2. **Repair filesystem (backup first!):**
   ```bash
   ssh user@fedora-ip "sudo fsck -y /dev/sdb1"
   ```

3. **Verify filesystem type:**
   ```bash
   ssh user@fedora-ip "sudo blkid /dev/sdb1"
   ```

---

## Package Installation Issues

### Problem: Package not found

**Symptoms:**
```
No package <package-name> available.
```

**Solutions:**

1. **Enable RPM Fusion:**
   ```bash
   ssh user@fedora-ip "sudo dnf install --nogpgcheck \
     https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
     https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
   ```

2. **Update package cache:**
   ```bash
   ssh user@fedora-ip "sudo dnf update --refresh"
   ```

3. **Search for alternative package:**
   ```bash
   ssh user@fedora-ip "dnf search <package-name>"
   ```

4. **Install manually if needed:**
   ```bash
   ssh user@fedora-ip "sudo dnf install <alternative-package>"
   ```

### Problem: GPG key issues

**Symptoms:**
```
Public key for <package> is not installed
```

**Solutions:**

1. **Import RPM Fusion keys:**
   ```bash
   ssh user@fedora-ip "sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-*"
   ```

2. **Skip GPG check (temporary):**
   ```bash
   ssh user@fedora-ip "sudo dnf install --nogpgcheck <package>"
   ```

---

## NVIDIA/CUDA Issues

### Problem: NVIDIA driver not loading

**Symptoms:**
```bash
nvidia-smi
# NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver
```

**Solutions:**

1. **Check if driver is installed:**
   ```bash
   rpm -qa | grep nvidia
   ```

2. **Wait for kernel module to build:**
   ```bash
   # This can take 5-10 minutes
   sudo akmods --force
   sudo dracut --force
   ```

3. **Check module status:**
   ```bash
   lsmod | grep nvidia
   modinfo nvidia
   ```

4. **Load module manually:**
   ```bash
   sudo modprobe nvidia
   ```

5. **Reboot:**
   ```bash
   sudo reboot
   ```

6. **Check for secure boot:**
   ```bash
   mokutil --sb-state
   # If enabled, you may need to disable it or sign the module
   ```

### Problem: Nouveau conflict

**Symptoms:**
```
NVIDIA driver fails to load, nouveau is loaded
```

**Solutions:**

1. **Verify nouveau is blacklisted:**
   ```bash
   cat /etc/modprobe.d/blacklist-nouveau.conf
   ```

2. **Update initramfs:**
   ```bash
   sudo dracut --force
   sudo reboot
   ```

3. **Check loaded modules:**
   ```bash
   lsmod | grep nouveau
   # Should return nothing
   ```

### Problem: CUDA not found

**Symptoms:**
```bash
nvcc --version
# command not found
```

**Solutions:**

1. **Check CUDA installation:**
   ```bash
   ls -la /usr/local/cuda
   ```

2. **Add to PATH:**
   ```bash
   echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
   echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Reinstall CUDA:**
   ```bash
   sudo dnf install cuda cuda-toolkit
   ```

---

## Theme Issues

### Problem: Theme not applied

**Symptoms:**
- GNOME looks like default Fedora theme
- WhiteSur theme not visible

**Solutions:**

1. **Check theme installation:**
   ```bash
   ls /usr/share/themes/ | grep WhiteSur
   ls ~/.local/share/themes/ | grep WhiteSur
   ```

2. **Apply manually with GNOME Tweaks:**
   ```bash
   gnome-tweaks
   # Appearance → Themes → Applications: WhiteSur-Dark
   ```

3. **Enable User Themes extension:**
   ```bash
   gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com
   ```

4. **Apply via gsettings:**
   ```bash
   gsettings set org.gnome.desktop.interface gtk-theme "WhiteSur-Dark"
   gsettings set org.gnome.desktop.wm.preferences theme "WhiteSur-Dark"
   gsettings set org.gnome.shell.extensions.user-theme name "WhiteSur-Dark"
   ```

5. **Log out and log back in**

### Problem: Extensions not working

**Symptoms:**
```
Extensions appear installed but not active
```

**Solutions:**

1. **Check GNOME Shell version compatibility:**
   ```bash
   gnome-shell --version
   ```

2. **Restart GNOME Shell:**
   - Press Alt+F2
   - Type 'r' and press Enter
   - Or log out and back in

3. **Enable extensions:**
   ```bash
   gnome-extensions list
   gnome-extensions enable <extension-id>
   ```

4. **Install Extensions app:**
   ```bash
   sudo dnf install gnome-extensions-app
   ```

---

## Service Issues

### Problem: Service fails to start

**Symptoms:**
```
Failed to start <service-name>.service
```

**Solutions:**

1. **Check service status:**
   ```bash
   sudo systemctl status <service-name>
   ```

2. **Check logs:**
   ```bash
   sudo journalctl -u <service-name> -n 50
   ```

3. **Check configuration:**
   ```bash
   sudo <service-name> -t  # Test configuration
   ```

4. **Reset failed state:**
   ```bash
   sudo systemctl reset-failed <service-name>
   sudo systemctl start <service-name>
   ```

### Problem: Docker daemon not starting

**Symptoms:**
```
Cannot connect to the Docker daemon
```

**Solutions:**

1. **Check Docker status:**
   ```bash
   sudo systemctl status docker
   ```

2. **Start Docker:**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

3. **Check Docker socket:**
   ```bash
   ls -la /var/run/docker.sock
   sudo chmod 666 /var/run/docker.sock  # Temporary fix
   ```

4. **Add user to docker group:**
   ```bash
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

---

## Permission Issues

### Problem: Permission denied errors

**Symptoms:**
```
Permission denied when accessing /home or /var
```

**Solutions:**

1. **Check ownership:**
   ```bash
   ls -ld /home
   ls -ld /var
   ```

2. **Check SELinux contexts:**
   ```bash
   ls -Z /home
   ls -Z /var
   ```

3. **Restore SELinux contexts:**
   ```bash
   sudo restorecon -R /home
   sudo restorecon -R /var
   ```

4. **Check file permissions:**
   ```bash
   ls -la /home/username
   # Fix if needed:
   sudo chown -R username:username /home/username
   ```

### Problem: SSH key authentication fails

**Symptoms:**
```
Permission denied (publickey)
```

**Solutions:**

1. **Check .ssh permissions:**
   ```bash
   ls -la ~/.ssh
   # Should be:
   # drwx------ .ssh
   # -rw------- authorized_keys
   # -rw------- id_rsa
   # -rw-r--r-- id_rsa.pub
   ```

2. **Fix permissions:**
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   ```

3. **Restore SELinux context:**
   ```bash
   restorecon -R ~/.ssh
   ```

---

## General Issues

### Problem: Playbook fails partway through

**Solutions:**

1. **Check the logs:**
   ```bash
   tail -f logs/ansible.log
   ```

2. **Run specific role:**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --tags <role-name>
   ```

3. **Continue from failed task:**
   - Fix the issue
   - Re-run the playbook (Ansible is idempotent)

4. **Skip failing tasks (if non-critical):**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --skip-tags <failing-role>
   ```

### Problem: System slow after migration

**Solutions:**

1. **Check disk I/O:**
   ```bash
   iostat -x 1
   ```

2. **Check memory:**
   ```bash
   free -h
   ```

3. **Check running services:**
   ```bash
   systemctl list-units --type=service --state=running
   ```

4. **Disable unnecessary services:**
   ```bash
   sudo systemctl disable <service-name>
   ```

### Problem: Need to rollback

**Solutions:**

1. **Restore Proxmox snapshot:**
   - Proxmox UI → VM → Snapshots
   - Select pre-migration snapshot
   - Click Rollback

2. **Reattach disks to Ubuntu:**
   - Detach from Fedora VM
   - Reattach to Ubuntu VM
   - Boot Ubuntu VM

---

## Getting Help

### Collect diagnostic information:

```bash
# System information
cat /etc/os-release
uname -a

# Disk information
lsblk
df -h
mount

# Package information
rpm -qa | wc -l
dnf list installed | grep -i nvidia

# Service status
systemctl status
systemctl --failed

# Logs
journalctl -p err -b
tail -100 /var/log/messages
cat logs/ansible.log

# NVIDIA (if applicable)
nvidia-smi
lsmod | grep nvidia
dmesg | grep -i nvidia
```

### Check these files:

- `/var/log/migration/` - Migration logs
- `logs/ansible.log` - Ansible execution log
- `/var/log/messages` - System log
- `journalctl -xe` - Recent system events

### Common log locations:

- Ansible: `logs/ansible.log`
- Migration: `/var/log/migration/`
- System: `/var/log/messages`
- Journal: `journalctl -xe`
- Boot: `journalctl -b`

---

## Prevention

### Before running migration:

1. ✅ Test SSH connectivity
2. ✅ Verify disk devices
3. ✅ Run in check mode first
4. ✅ Create VM snapshots
5. ✅ Review configuration files
6. ✅ Test on a clone first (if possible)

### Best practices:

- Always keep backups
- Test changes on non-production systems
- Document custom configurations
- Keep migration logs
- Review error messages carefully
- Use Proxmox snapshots liberally

---

**Remember:** Most issues can be resolved by checking logs and verifying configuration. Take your time and don't panic!
