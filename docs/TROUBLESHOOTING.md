# Troubleshooting Guide - v2.0# Troubleshooting Guide - v2.0



This guide covers common issues you might encounter during export from Ubuntu and import to Fedora.Common issues and solutions for LinMigrator export/import workflow.



## Table of ContentsCommon issues and solutions for the Ubuntu to Fedora migration.



- [Export Issues (Ubuntu)](#export-issues-ubuntu)## Table of Contents

- [Import Issues (Fedora)](#import-issues-fedora)

- [Package Mapping Issues](#package-mapping-issues)1. [Connection Issues](#connection-issues)

- [Disk Mounting Issues](#disk-mounting-issues)2. [Disk Mounting Issues](#disk-mounting-issues)

- [NVIDIA/CUDA Issues](#nvidiacuda-issues)3. [Package Installation Issues](#package-installation-issues)

- [Theme Issues](#theme-issues)4. [NVIDIA/CUDA Issues](#nvidiacuda-issues)

- [Encryption/Decryption Issues](#encryptiondecryption-issues)5. [Theme Issues](#theme-issues)

- [Git & Repository Issues](#git--repository-issues)6. [Service Issues](#service-issues)

- [General Issues](#general-issues)7. [Permission Issues](#permission-issues)

- [Getting Help](#getting-help)8. [General Issues](#general-issues)



------



## Export Issues (Ubuntu)## Connection Issues



### Export script fails to detect information### Problem: Cannot SSH to target system



**Problem:** `export.sh` doesn't detect packages, mounts, or services correctly.**Symptoms:**

```

**Solutions:**ssh: connect to host 192.168.1.100 port 22: Connection refused

```

1. **Check permissions:**

   ```bash**Solutions:**

   # Export must run with sudo for full detection

   sudo ./scripts/export.sh1. **Verify target is reachable:**

   ```   ```bash

   ping 192.168.1.100

2. **Verify detection commands:**   ```

   ```bash

   # Test individual detection commands2. **Check SSH service is running:**

   dpkg-query -W -f='${Package}\n' 2>/dev/null  # Packages   ```bash

   systemctl list-unit-files --state=enabled --no-pager  # Services   ssh user@fedora-ip "systemctl status sshd"

   lsblk -o NAME,SIZE,TYPE,MOUNTPOINT  # Disks   ```

   ```

3. **Check firewall:**

3. **Check for corrupted package database:**   ```bash

   ```bash   ssh user@fedora-ip "sudo firewall-cmd --list-all"

   sudo dpkg --configure -a   # Add SSH if needed:

   sudo apt update   sudo firewall-cmd --permanent --add-service=ssh

   ```   sudo firewall-cmd --reload

   ```

### Export directory not created

4. **Verify correct IP address:**

**Problem:** `exports/` directory not created or accessible.   ```bash

   ip addr show

**Solutions:**   ```



1. **Check disk space:**### Problem: Ansible ping fails

   ```bash

   df -h .**Symptoms:**

   ``````

fedora-vm | UNREACHABLE! => {"changed": false, "msg": "Failed to connect"}

2. **Verify write permissions:**```

   ```bash

   ls -ld .**Solutions:**

   # Should show write permission for your user

   ```1. **Test manual SSH first:**

   ```bash

3. **Create manually:**   ssh -v user@target-ip

   ```bash   ```

   mkdir -p exports

   chmod 755 exports2. **Check inventory file:**

   ```   ```bash

   cat inventory/hosts.ini

### Encryption fails   # Verify ansible_host and ansible_user

   ```

**Problem:** Encryption with `openssl` fails during export.

3. **Test with explicit credentials:**

**Solutions:**   ```bash

   ansible -i inventory/hosts.ini fedora_target -m ping -u root --ask-pass

1. **Verify openssl installed:**   ```

   ```bash

   which openssl4. **Check Python on target:**

   openssl version   ```bash

   ```   ssh user@target-ip "which python3"

   ```

2. **Check encryption key:**

   - Ensure you entered a strong key (8+ characters)---

   - Key is stored in `exports/encryption_key.txt`

   - **BACK THIS UP** before deleting Ubuntu system## Disk Mounting Issues



3. **Test encryption manually:**### Problem: Disk device not found

   ```bash

   echo "test" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:yourkey**Symptoms:**

   ``````

FAILED! => {"msg": "Disk /dev/sdb1 not found!"}

### Hardware detection incomplete```



**Problem:** Some hardware (GPU, network cards) not detected.**Solutions:**



**Solutions:**1. **Check available disks:**

   ```bash

1. **Check for devices:**   ssh user@fedora-ip "lsblk"

   ```bash   ```

   lspci | grep -i vga  # GPUs

   lspci | grep -i network  # Network cards2. **Verify disks attached in Proxmox:**

   ip link show  # Network interfaces   - Proxmox UI → Select VM → Hardware

   ```   - Ensure disks are attached

   - Note the correct device names

2. **Install detection tools:**

   ```bash3. **Update group_vars:**

   sudo apt install pciutils usbutils lshw   ```bash

   ```   vim group_vars/fedora_target.yml

   # Update var_disk_device and home_disk_device

3. **Manually add to export config:**   ```

   - Edit `exports/system_export_*/hardware.txt`

   - Add missing hardware info4. **Check disk is visible:**

   ```bash

### Flatpak export incomplete   ssh user@fedora-ip "sudo fdisk -l"

   ```

**Problem:** Flatpak apps not exported correctly.

### Problem: Disk already mounted

**Solutions:**

**Symptoms:**

1. **Verify Flatpak installed:**```

   ```bashmount: /var: /dev/sdb1 already mounted on /var

   flatpak --version```

   flatpak list

   ```**Solutions:**



2. **Check Flatpak data:**1. **Check current mounts:**

   ```bash   ```bash

   ls -la ~/.var/app/  # User app data   ssh user@fedora-ip "mount | grep -E '(/var|/home)'"

   ls -la ~/.local/share/flatpak/  # User apps   ```

   ```

2. **Unmount if needed:**

3. **Re-export Flatpaks:**   ```bash

   ```bash   ssh user@fedora-ip "sudo umount /var"

   flatpak list --app --columns=application > flatpak_apps.txt   ssh user@fedora-ip "sudo umount /home"

   ```   ```



---3. **Re-run playbook:**

   ```bash

## Import Issues (Fedora)   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --tags mount

   ```

### Import script won't start

### Problem: Filesystem corruption

**Problem:** `import.sh` fails immediately or won't execute.

**Symptoms:**

**Solutions:**```

mount: wrong fs type, bad option, bad superblock

1. **Check if running on Fedora:**```

   ```bash

   cat /etc/os-release**Solutions:**

   # Should show "Fedora Linux"

   ```1. **Check filesystem:**

   ```bash

2. **Verify script permissions:**   ssh user@fedora-ip "sudo fsck -n /dev/sdb1"

   ```bash   ```

   chmod +x scripts/import.sh

   ```2. **Repair filesystem (backup first!):**

   ```bash

3. **Run with sudo:**   ssh user@fedora-ip "sudo fsck -y /dev/sdb1"

   ```bash   ```

   sudo ./scripts/import.sh

   ```3. **Verify filesystem type:**

   ```bash

4. **Check for bash:**   ssh user@fedora-ip "sudo blkid /dev/sdb1"

   ```bash   ```

   which bash

   # Should show /usr/bin/bash---

   ```

## Package Installation Issues

### Decryption fails

### Problem: Package not found

**Problem:** Cannot decrypt exported data.

**Symptoms:**

**Solutions:**```

No package <package-name> available.

1. **Verify encryption key file exists:**```

   ```bash

   ls -la exports/encryption_key.txt**Solutions:**

   cat exports/encryption_key.txt  # Should show your key

   ```1. **Enable RPM Fusion:**

   ```bash

2. **Test decryption manually:**   ssh user@fedora-ip "sudo dnf install --nogpgcheck \

   ```bash     https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \

   KEY=$(cat exports/encryption_key.txt)     https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

   openssl enc -aes-256-cbc -d -pbkdf2 -in exports/system_export_*/packages.txt.enc -pass pass:$KEY   ```

   ```

2. **Update package cache:**

3. **Check for typos in key:**   ```bash

   - Key is case-sensitive   ssh user@fedora-ip "sudo dnf update --refresh"

   - No extra spaces or newlines   ```

   - Must match exactly from Ubuntu export

3. **Search for alternative package:**

4. **Re-export if key lost:**   ```bash

   - If you lost the encryption key, you must re-run export on Ubuntu   ssh user@fedora-ip "dnf search <package-name>"

   - The encrypted data cannot be recovered without the key   ```



### Package installation fails massively4. **Install manually if needed:**

   ```bash

**Problem:** Many packages fail to install on Fedora.   ssh user@fedora-ip "sudo dnf install <alternative-package>"

   ```

**Solutions:**

### Problem: GPG key issues

1. **Check network/repo connection:**

   ```bash**Symptoms:**

   sudo dnf check-update```

   sudo dnf repolistPublic key for <package> is not installed

   ``````



2. **Update DNF cache:****Solutions:**

   ```bash

   sudo dnf clean all1. **Import RPM Fusion keys:**

   sudo dnf makecache   ```bash

   ```   ssh user@fedora-ip "sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-*"

   ```

3. **Enable required repositories:**

   ```bash2. **Skip GPG check (temporary):**

   # Enable RPM Fusion (for multimedia, etc.)   ```bash

   sudo dnf install -y \   ssh user@fedora-ip "sudo dnf install --nogpgcheck <package>"

     https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \   ```

     https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

   ```---



4. **Check failed packages list:**## NVIDIA/CUDA Issues

   ```bash

   # Import script creates this during package mapping### Problem: NVIDIA driver not loading

   cat /tmp/failed_packages.txt

   **Symptoms:**

   # Try installing manually```bash

   sudo dnf search <package-name>nvidia-smi

   ```# NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver

```

5. **Review package transformation:**

   - See [PACKAGE_MAPPING.md](PACKAGE_MAPPING.md) for common mappings**Solutions:**

   - Some Ubuntu packages have completely different equivalents on Fedora

1. **Check if driver is installed:**

### Services fail to enable   ```bash

   rpm -qa | grep nvidia

**Problem:** Systemd services won't enable on Fedora.   ```



**Solutions:**2. **Wait for kernel module to build:**

   ```bash

1. **Check service status:**   # This can take 5-10 minutes

   ```bash   sudo akmods --force

   systemctl status <service-name>   sudo dracut --force

   ```   ```



2. **List available services:**3. **Check module status:**

   ```bash   ```bash

   systemctl list-unit-files | grep <service>   lsmod | grep nvidia

   ```   modinfo nvidia

   ```

3. **Common service name differences:**

   - `apache2` → `httpd`4. **Load module manually:**

   - `mysql` → `mariadb`   ```bash

   - Some Ubuntu services don't exist on Fedora   sudo modprobe nvidia

   ```

4. **Enable manually:**

   ```bash5. **Reboot:**

   sudo systemctl enable <service-name>   ```bash

   sudo systemctl start <service-name>   sudo reboot

   ```   ```



5. **Check for masked services:**6. **Check for secure boot:**

   ```bash   ```bash

   systemctl list-unit-files --state=masked   mokutil --sb-state

   # Unmask if needed:   # If enabled, you may need to disable it or sign the module

   sudo systemctl unmask <service-name>   ```

   ```

### Problem: Nouveau conflict

### Ansible playbook fails

**Symptoms:**

**Problem:** Ansible execution fails during import.```

NVIDIA driver fails to load, nouveau is loaded

**Solutions:**```



1. **Check Ansible installation:****Solutions:**

   ```bash

   ansible --version1. **Verify nouveau is blacklisted:**

   which ansible-playbook   ```bash

   ```   cat /etc/modprobe.d/blacklist-nouveau.conf

   ```

2. **Test Ansible manually:**

   ```bash2. **Update initramfs:**

   cd ansible   ```bash

   ansible-playbook -i inventory/local bootstrap.yml --check   sudo dracut --force

   ```   sudo reboot

   ```

3. **View detailed error:**

   ```bash3. **Check loaded modules:**

   # Run with verbose output   ```bash

   ansible-playbook -i inventory/local bootstrap.yml -vvv   lsmod | grep nouveau

   ```   # Should return nothing

   ```

4. **Check inventory file:**

   ```bash### Problem: CUDA not found

   cat ansible/inventory/local

   # Should have localhost entry**Symptoms:**

   ``````bash

nvcc --version

5. **Verify Ansible can connect:**# command not found

   ```bash```

   ansible -i inventory/local localhost -m ping

   ```**Solutions:**



### GNOME extensions not working1. **Check CUDA installation:**

   ```bash

**Problem:** GNOME Shell extensions don't load after import.   ls -la /usr/local/cuda

   ```

**Solutions:**

2. **Add to PATH:**

1. **Check GNOME Shell version compatibility:**   ```bash

   ```bash   echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc

   gnome-shell --version   echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

   # Extensions must support this version   source ~/.bashrc

   ```   ```



2. **Install gnome-extensions-app:**3. **Reinstall CUDA:**

   ```bash   ```bash

   sudo dnf install -y gnome-extensions-app   sudo dnf install cuda cuda-toolkit

   ```   ```



3. **Enable extensions manually:**---

   ```bash

   gnome-extensions list## Theme Issues

   gnome-extensions enable <extension-uuid>

   ```### Problem: Theme not applied



4. **Re-download extensions:****Symptoms:**

   - Some extensions may need Fedora-specific versions- GNOME looks like default Fedora theme

   - Visit https://extensions.gnome.org- WhiteSur theme not visible

   - Install compatible versions

**Solutions:**

5. **Restart GNOME Shell:**

   - Press `Alt+F2`1. **Check theme installation:**

   - Type `r` and press Enter   ```bash

   - Or log out and back in   ls /usr/share/themes/ | grep WhiteSur

   ls ~/.local/share/themes/ | grep WhiteSur

---   ```



## Package Mapping Issues2. **Apply manually with GNOME Tweaks:**

   ```bash

### Understanding package mapping failures   gnome-tweaks

   # Appearance → Themes → Applications: WhiteSur-Dark

The import script uses intelligent package mapping:   ```



1. **Transformation rules** - Ubuntu names → Fedora names3. **Enable User Themes extension:**

2. **DNF exact match** - `dnf info <package>`   ```bash

3. **DNF fuzzy search** - `dnf search <package>`   gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

4. **Fallback** - Mark as failed for manual review   ```



### High failure rate (>30%)4. **Apply via gsettings:**

   ```bash

**Problem:** More than 30% of packages fail to map.   gsettings set org.gnome.desktop.interface gtk-theme "WhiteSur-Dark"

   gsettings set org.gnome.desktop.wm.preferences theme "WhiteSur-Dark"

**Solutions:**   gsettings set org.gnome.shell.extensions.user-theme name "WhiteSur-Dark"

   ```

1. **Check DNF repositories enabled:**

   ```bash5. **Log out and log back in**

   dnf repolist

   # Should show: fedora, updates, RPM Fusion (optional)### Problem: Extensions not working

   ```

**Symptoms:**

2. **Enable additional repos:**```

   ```bashExtensions appear installed but not active

   # RPM Fusion (recommended)```

   sudo dnf install -y rpmfusion-free-release rpmfusion-nonfree-release

   **Solutions:**

   # EPEL (if needed)

   sudo dnf install -y epel-release1. **Check GNOME Shell version compatibility:**

   ```   ```bash

   gnome-shell --version

3. **Review failed packages:**   ```

   ```bash

   cat /tmp/failed_packages.txt2. **Restart GNOME Shell:**

   ```   - Press Alt+F2

   - Type 'r' and press Enter

4. **Check for Ubuntu-specific packages:**   - Or log out and back in

   - Many failed packages may be Ubuntu-specific (e.g., `ubuntu-desktop`)

   - PPAs packages won't have Fedora equivalents3. **Enable extensions:**

   - Some packages may use completely different names   ```bash

   gnome-extensions list

5. **Manual mapping:**   gnome-extensions enable <extension-id>

   - See [PACKAGE_MAPPING.md](PACKAGE_MAPPING.md) for common mappings   ```

   - Search manually: `dnf search <functionality>`

4. **Install Extensions app:**

### Specific package won't map   ```bash

   sudo dnf install gnome-extensions-app

**Problem:** Important package consistently fails to map.   ```



**Solutions:**---



1. **Search manually:**## Service Issues

   ```bash

   dnf search <package-name>### Problem: Service fails to start

   dnf provides <package-name>

   ```**Symptoms:**

```

2. **Check for alternative names:**Failed to start <service-name>.service

   ```bash```

   # Example: Ubuntu's build-essential

   dnf groupinfo "Development Tools"**Solutions:**

   sudo dnf groupinstall "Development Tools"

   ```1. **Check service status:**

   ```bash

3. **Common manual mappings:**   sudo systemctl status <service-name>

   ```bash   ```

   # Ubuntu → Fedora

   build-essential → @development-tools2. **Check logs:**

   apache2 → httpd   ```bash

   apache2-dev → httpd-devel   sudo journalctl -u <service-name> -n 50

   mysql-server → mariadb-server   ```

   libmysqlclient-dev → mariadb-connector-c-devel

   python3-dev → python3-devel3. **Check configuration:**

   libpq-dev → libpq-devel   ```bash

   ```   sudo <service-name> -t  # Test configuration

   ```

4. **Install from alternative source:**

   - Flatpak: `flatpak install flathub <app>`4. **Reset failed state:**

   - AppImage: Download from app website   ```bash

   - Source: Build from source code   sudo systemctl reset-failed <service-name>

   sudo systemctl start <service-name>

### Development packages missing   ```



**Problem:** Development libraries (-dev packages) not found.### Problem: Docker daemon not starting



**Solutions:****Symptoms:**

```

1. **Install development groups:**Cannot connect to the Docker daemon

   ```bash```

   sudo dnf groupinstall "Development Tools" "Development Libraries"

   ```**Solutions:**



2. **Remember naming difference:**1. **Check Docker status:**

   - Ubuntu: `-dev` suffix   ```bash

   - Fedora: `-devel` suffix   sudo systemctl status docker

   ```bash   ```

   # The import script transforms these automatically

   libcurl-dev → libcurl-devel2. **Start Docker:**

   libssl-dev → openssl-devel   ```bash

   ```   sudo systemctl start docker

   sudo systemctl enable docker

3. **Search for development packages:**   ```

   ```bash

   dnf search <lib>-devel3. **Check Docker socket:**

   ```   ```bash

   ls -la /var/run/docker.sock

---   sudo chmod 666 /var/run/docker.sock  # Temporary fix

   ```

## Disk Mounting Issues

4. **Add user to docker group:**

### Cannot find disk by UUID   ```bash

   sudo usermod -aG docker $USER

**Problem:** Disks from Ubuntu system can't be found by UUID on Fedora.   # Log out and back in

   ```

**Solutions:**

---

1. **List all disks:**

   ```bash## Permission Issues

   lsblk -f

   sudo blkid### Problem: Permission denied errors

   ```

**Symptoms:**

2. **Verify disk is connected:**```

   - For VM: Check disk is attached in hypervisorPermission denied when accessing /home or /var

   - For bare metal: Check cables/connections```

   - For LUKS: Decrypt first (see below)

**Solutions:**

3. **UUID changed:**

   - If you reformatted or reinstalled, UUIDs change1. **Check ownership:**

   - Edit `imports/IMPORT_SETTINGS` to update UUIDs   ```bash

   - Or use device names: `/dev/sda1` instead of UUID   ls -ld /home

   ls -ld /var

4. **Try manual mount:**   ```

   ```bash

   sudo mkdir -p /mnt/test2. **Check SELinux contexts:**

   sudo mount /dev/sdX1 /mnt/test   ```bash

   # If this works, UUID might be wrong in settings   ls -Z /home

   ```   ls -Z /var

   ```

### LUKS encrypted drives won't open

3. **Restore SELinux contexts:**

**Problem:** Cannot decrypt or mount LUKS encrypted disks.   ```bash

   sudo restorecon -R /home

**Solutions:**   sudo restorecon -R /var

   ```

1. **Check LUKS device:**

   ```bash4. **Check file permissions:**

   sudo cryptsetup luksDump /dev/sdX1   ```bash

   ```   ls -la /home/username

   # Fix if needed:

2. **Open manually:**   sudo chown -R username:username /home/username

   ```bash   ```

   sudo cryptsetup luksOpen /dev/sdX1 my_encrypted_drive

   # Enter your LUKS password### Problem: SSH key authentication fails

   ```

**Symptoms:**

3. **Mount after opening:**```

   ```bashPermission denied (publickey)

   sudo mkdir -p /mnt/encrypted```

   sudo mount /dev/mapper/my_encrypted_drive /mnt/encrypted

   ```**Solutions:**



4. **Update /etc/crypttab:**1. **Check .ssh permissions:**

   ```bash   ```bash

   sudo nano /etc/crypttab   ls -la ~/.ssh

   # Add line:   # Should be:

   my_encrypted_drive UUID=<your-luks-uuid> none luks   # drwx------ .ssh

   ```   # -rw------- authorized_keys

   # -rw------- id_rsa

5. **Common LUKS issues:**   # -rw-r--r-- id_rsa.pub

   - Wrong password (LUKS passwords are case-sensitive)   ```

   - Corrupted LUKS header

   - Missing cryptsetup: `sudo dnf install -y cryptsetup`2. **Fix permissions:**

   ```bash

### NFS mounts fail   chmod 700 ~/.ssh

   chmod 600 ~/.ssh/authorized_keys

**Problem:** Network File System mounts don't work.   chmod 600 ~/.ssh/id_rsa

   chmod 644 ~/.ssh/id_rsa.pub

**Solutions:**   ```



1. **Install NFS utilities:**3. **Restore SELinux context:**

   ```bash   ```bash

   sudo dnf install -y nfs-utils   restorecon -R ~/.ssh

   sudo systemctl enable --now nfs-client.target   ```

   ```

---

2. **Test NFS server reachable:**

   ```bash## General Issues

   showmount -e <nfs-server-ip>

   ```### Problem: Playbook fails partway through



3. **Mount manually:****Solutions:**

   ```bash

   sudo mount -t nfs <server>:/export/path /mnt/nfs1. **Check the logs:**

   ```   ```bash

   tail -f logs/ansible.log

4. **Add to /etc/fstab:**   ```

   ```bash

   sudo nano /etc/fstab2. **Run specific role:**

   # Add line:   ```bash

   <server>:/export/path /mnt/nfs nfs defaults,_netdev 0 0   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --tags <role-name>

   ```   ```



5. **Firewall issues:**3. **Continue from failed task:**

   ```bash   - Fix the issue

   # Allow NFS through firewall   - Re-run the playbook (Ansible is idempotent)

   sudo firewall-cmd --permanent --add-service=nfs

   sudo firewall-cmd --reload4. **Skip failing tasks (if non-critical):**

   ```   ```bash

   ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --skip-tags <failing-role>

### CIFS/SMB shares won't mount   ```



**Problem:** Windows/Samba shares don't mount.### Problem: System slow after migration



**Solutions:****Solutions:**



1. **Install CIFS utilities:**1. **Check disk I/O:**

   ```bash   ```bash

   sudo dnf install -y cifs-utils   iostat -x 1

   ```   ```



2. **Test mount manually:**2. **Check memory:**

   ```bash   ```bash

   sudo mount -t cifs //server/share /mnt/smb -o username=user,password=pass   free -h

   ```   ```



3. **Use credentials file (more secure):**3. **Check running services:**

   ```bash   ```bash

   # Create credentials file   systemctl list-units --type=service --state=running

   nano ~/.smbcredentials   ```

   username=your_username

   password=your_password4. **Disable unnecessary services:**

   domain=WORKGROUP   ```bash

      sudo systemctl disable <service-name>

   chmod 600 ~/.smbcredentials   ```

   

   # Mount using credentials file### Problem: Need to rollback

   sudo mount -t cifs //server/share /mnt/smb -o credentials=/home/user/.smbcredentials

   ```**Solutions:**



4. **Add to /etc/fstab:**1. **Restore Proxmox snapshot:**

   ```bash   - Proxmox UI → VM → Snapshots

   //server/share /mnt/smb cifs credentials=/home/user/.smbcredentials,_netdev 0 0   - Select pre-migration snapshot

   ```   - Click Rollback



---2. **Reattach disks to Ubuntu:**

   - Detach from Fedora VM

## NVIDIA/CUDA Issues   - Reattach to Ubuntu VM

   - Boot Ubuntu VM

### NVIDIA drivers not working after import

---

**Problem:** NVIDIA GPU not detected or drivers not loaded.

## Getting Help

**Solutions:**

### Collect diagnostic information:

1. **Check if GPU detected:**

   ```bash```bash

   lspci | grep -i nvidia# System information

   # Should show your NVIDIA cardcat /etc/os-release

   ```uname -a



2. **Install NVIDIA drivers on Fedora:**# Disk information

   ```bashlsblk

   # Enable RPM Fusion non-free repositorydf -h

   sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpmmount

   

   # Install NVIDIA driver# Package information

   sudo dnf install -y akmod-nvidiarpm -qa | wc -l

   sudo dnf install -y xorg-x11-drv-nvidia-cuda  # For CUDA supportdnf list installed | grep -i nvidia

   ```

# Service status

3. **Wait for kernel module build:**systemctl status

   ```bashsystemctl --failed

   # akmods builds driver for your kernel

   sudo akmods --force# Logs

   # Wait 5-10 minutesjournalctl -p err -b

   tail -100 /var/log/messages

   # Check if module built:cat logs/ansible.log

   modinfo nvidia

   ```# NVIDIA (if applicable)

nvidia-smi

4. **Reboot:**lsmod | grep nvidia

   ```bashdmesg | grep -i nvidia

   sudo reboot```

   ```

### Check these files:

5. **Verify driver loaded:**

   ```bash- `/var/log/migration/` - Migration logs

   nvidia-smi- `logs/ansible.log` - Ansible execution log

   # Should show GPU info and driver version- `/var/log/messages` - System log

   ```- `journalctl -xe` - Recent system events



### CUDA toolkit issues### Common log locations:



**Problem:** CUDA applications don't work or can't find CUDA.- Ansible: `logs/ansible.log`

- Migration: `/var/log/migration/`

**Solutions:**- System: `/var/log/messages`

- Journal: `journalctl -xe`

1. **Install CUDA from RPM Fusion:**- Boot: `journalctl -b`

   ```bash

   sudo dnf install -y xorg-x11-drv-nvidia-cuda---

   sudo dnf install -y cuda

   ```## Prevention



2. **Or install from NVIDIA (official):**### Before running migration:

   ```bash

   # Download .run file from NVIDIA website1. ✅ Test SSH connectivity

   # Follow NVIDIA's installation guide for Fedora2. ✅ Verify disk devices

   ```3. ✅ Run in check mode first

4. ✅ Create VM snapshots

3. **Set environment variables:**5. ✅ Review configuration files

   ```bash6. ✅ Test on a clone first (if possible)

   echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc

   echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc### Best practices:

   source ~/.bashrc

   ```- Always keep backups

- Test changes on non-production systems

4. **Verify CUDA:**- Document custom configurations

   ```bash- Keep migration logs

   nvcc --version- Review error messages carefully

   ```- Use Proxmox snapshots liberally



### Nvidia-smi not found---



**Problem:** `nvidia-smi` command not available.**Remember:** Most issues can be resolved by checking logs and verifying configuration. Take your time and don't panic!


**Solutions:**

1. **Install CUDA package:**
   ```bash
   sudo dnf install -y xorg-x11-drv-nvidia-cuda-libs
   ```

2. **Check PATH:**
   ```bash
   which nvidia-smi
   # Should be in /usr/bin/nvidia-smi
   ```

3. **Reboot if just installed:**
   ```bash
   sudo reboot
   ```

---

## Theme Issues

### GTK theme not applied

**Problem:** GNOME theme doesn't match Ubuntu setup.

**Solutions:**

1. **Install GNOME Tweaks:**
   ```bash
   sudo dnf install -y gnome-tweaks
   ```

2. **Install missing theme:**
   ```bash
   # Check your imported theme name
   cat exports/system_export_*/gnome_settings.txt | grep theme
   
   # Search for theme
   dnf search <theme-name>
   
   # Common themes
   sudo dnf install -y arc-theme papirus-icon-theme
   ```

3. **Apply theme manually:**
   ```bash
   gsettings set org.gnome.desktop.interface gtk-theme "Arc-Dark"
   gsettings set org.gnome.desktop.interface icon-theme "Papirus"
   ```

4. **Install from Pling/Gnome-look:**
   - Download theme from https://www.gnome-look.org
   - Extract to `~/.themes/` (GTK) or `~/.icons/` (icons)
   - Select in GNOME Tweaks

### Icon theme missing

**Problem:** Icons don't look right or are missing.

**Solutions:**

1. **Install icon pack:**
   ```bash
   sudo dnf install -y papirus-icon-theme
   sudo dnf install -y breeze-icon-theme
   ```

2. **Install manually:**
   ```bash
   mkdir -p ~/.icons
   # Download icon theme .tar.gz
   tar -xzf theme.tar.gz -C ~/.icons/
   ```

3. **Apply via GNOME Tweaks:**
   - Open GNOME Tweaks
   - Go to Appearance → Icons
   - Select your icon theme

4. **Rebuild icon cache:**
   ```bash
   gtk-update-icon-cache ~/.icons/<theme-name>
   ```

### Fonts look different

**Problem:** Fonts don't match Ubuntu appearance.

**Solutions:**

1. **Install Microsoft fonts (optional):**
   ```bash
   sudo dnf install -y mscore-fonts-all
   ```

2. **Install additional fonts:**
   ```bash
   sudo dnf install -y google-noto-*-fonts
   sudo dnf install -y liberation-fonts
   ```

3. **Copy fonts from Ubuntu:**
   ```bash
   # From your Ubuntu backup/export
   cp -r /path/to/ubuntu/home/.fonts ~/
   fc-cache -f -v
   ```

4. **Configure font rendering:**
   ```bash
   gnome-tweaks
   # Go to Fonts section
   # Adjust Hinting, Antialiasing, Scaling Factor
   ```

---

## Encryption/Decryption Issues

### Lost encryption key

**Problem:** Cannot find `encryption_key.txt` file.

**Solutions:**

1. **Check exports directory:**
   ```bash
   find exports/ -name "encryption_key.txt"
   ls -la exports/encryption_key.txt
   ```

2. **Check backup locations:**
   - USB drive where you copied exports
   - Cloud storage backup
   - Original Ubuntu system (if still accessible)

3. **If truly lost:**
   - **ENCRYPTED DATA IS UNRECOVERABLE** without the key
   - You must re-run export on Ubuntu system
   - Store key securely this time (password manager, USB stick)

### Decryption produces garbage

**Problem:** Decrypted files contain unreadable data.

**Solutions:**

1. **Verify encryption key is correct:**
   ```bash
   cat exports/encryption_key.txt
   # Should be your original key with no extra characters
   ```

2. **Check encryption was successful:**
   ```bash
   ls -lh exports/system_export_*/*.enc
   # Files should have reasonable sizes
   ```

3. **Test decryption manually:**
   ```bash
   KEY=$(cat exports/encryption_key.txt)
   openssl enc -aes-256-cbc -d -pbkdf2 \
     -in exports/system_export_*/packages.txt.enc \
     -pass pass:$KEY \
     -out /tmp/test_decrypt.txt
   
   cat /tmp/test_decrypt.txt
   # Should show package names
   ```

4. **Files may be corrupted:**
   - Possible corruption during USB transfer
   - Network copy interrupted
   - Disk errors
   - Solution: Re-run export on Ubuntu

### OpenSSL version mismatch

**Problem:** Different OpenSSL versions between Ubuntu and Fedora cause issues.

**Solutions:**

1. **Check OpenSSL version:**
   ```bash
   openssl version
   ```

2. **Export uses these parameters:**
   ```bash
   openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:KEY
   ```

3. **Both systems support these by default:**
   - Ubuntu 20.04+ and Fedora 33+ use compatible OpenSSL
   - If using older Ubuntu, specify `-md sha256`

4. **Manual decrypt with compatibility:**
   ```bash
   openssl enc -aes-256-cbc -d -salt -pbkdf2 -md sha256 \
     -in file.enc -pass pass:KEY -out file.txt
   ```

---

## Git & Repository Issues

### Git configuration not preserved

**Problem:** Git user name, email, or other config not migrated.

**Solutions:**

1. **Check exported git config:**
   ```bash
   cat exports/system_export_*/git_config.txt
   ```

2. **Set manually:**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"
   ```

3. **Import full config:**
   ```bash
   # If exported from Ubuntu ~/.gitconfig
   cp /path/to/ubuntu/.gitconfig ~/
   ```

4. **Common git settings:**
   ```bash
   git config --global core.editor nano
   git config --global init.defaultBranch main
   git config --global pull.rebase false
   ```

### SSH keys for GitHub/GitLab missing

**Problem:** Can't push/pull from Git remotes - SSH auth fails.

**Solutions:**

1. **Copy SSH keys from Ubuntu:**
   ```bash
   # From your Ubuntu backup
   mkdir -p ~/.ssh
   cp /path/to/ubuntu/.ssh/id_* ~/.ssh/
   chmod 600 ~/.ssh/id_*
   chmod 700 ~/.ssh
   ```

2. **Or generate new keys:**
   ```bash
   ssh-keygen -t ed25519 -C "your@email.com"
   ```

3. **Add to GitHub/GitLab:**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # Copy this and add to GitHub/GitLab SSH keys
   ```

4. **Test connection:**
   ```bash
   ssh -T git@github.com
   ssh -T git@gitlab.com
   ```

### Git repositories in wrong location

**Problem:** Cloned repos not in expected directories.

**Solutions:**

1. **Check exported mount points:**
   ```bash
   cat exports/system_export_*/mount_points.txt
   ```

2. **Update disk mounting:**
   - Edit `imports/IMPORT_SETTINGS`
   - Add mount points for your repos
   - Re-run import or mount manually

3. **Clone repos again:**
   ```bash
   mkdir -p ~/dev/repos
   cd ~/dev/repos
   git clone git@github.com:yourusername/linmigrator.git
   ```

---

## General Issues

### Import takes extremely long

**Problem:** Import script runs for hours.

**Solutions:**

1. **This is normal for many packages:**
   - 500+ packages can take 1-2 hours
   - DNF search for each package adds time
   - Network speed affects download time

2. **Speed up future imports:**
   - Enable fastest mirror: `sudo dnf config-manager --set-enabled fastestmirror`
   - Use local mirror if available
   - Reduce package list (remove unused packages before export)

3. **Monitor progress:**
   ```bash
   # Import shows progress every 10 packages
   # Watch for "Mapping packages..." section
   ```

4. **Run in background:**
   ```bash
   sudo ./scripts/import.sh > import.log 2>&1 &
   tail -f import.log
   ```

### SELinux denials after import

**Problem:** Applications fail with SELinux permission denied errors.

**Solutions:**

1. **Check SELinux status:**
   ```bash
   getenforce
   # Shows: Enforcing, Permissive, or Disabled
   ```

2. **View denials:**
   ```bash
   sudo ausearch -m avc -ts recent
   ```

3. **Temporarily set permissive:**
   ```bash
   sudo setenforce 0
   # Test if app works now
   # If yes, SELinux is the issue
   ```

4. **Fix SELinux contexts:**
   ```bash
   # Restore default contexts
   sudo restorecon -Rv /home
   sudo restorecon -Rv /path/to/mounted/disk
   ```

5. **Create SELinux policy:**
   ```bash
   sudo ausearch -m avc -ts recent | audit2allow -M mypolicy
   sudo semodule -i mypolicy.pp
   ```

### Flatpak apps won't start

**Problem:** Flatpak applications don't launch after import.

**Solutions:**

1. **Install Flatpak on Fedora:**
   ```bash
   sudo dnf install -y flatpak
   ```

2. **Add Flathub repository:**
   ```bash
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   ```

3. **List imported flatpaks:**
   ```bash
   cat exports/system_export_*/flatpak_list.txt
   ```

4. **Install flatpaks:**
   ```bash
   # Import script should handle this, but if not:
   while read app; do
     flatpak install -y flathub "$app"
   done < exports/system_export_*/flatpak_list.txt
   ```

5. **Update flatpaks:**
   ```bash
   flatpak update
   ```

### Systemd user services not working

**Problem:** User-level systemd services don't run.

**Solutions:**

1. **Check user services:**
   ```bash
   systemctl --user list-unit-files
   ```

2. **Enable lingering (services run without login):**
   ```bash
   loginctl enable-linger $USER
   ```

3. **Start services:**
   ```bash
   systemctl --user enable <service-name>
   systemctl --user start <service-name>
   ```

4. **Copy service files:**
   ```bash
   mkdir -p ~/.config/systemd/user/
   # Copy from Ubuntu backup
   cp /path/to/ubuntu/.config/systemd/user/* ~/.config/systemd/user/
   systemctl --user daemon-reload
   ```

---

## Getting Help

### Documentation

- [Quick Start Guide](QUICK_START.md) - Basic usage
- [Export Guide](EXPORT_GUIDE.md) - Detailed export process
- [Import Guide](IMPORT_GUIDE.md) - Detailed import process
- [Package Mapping Guide](PACKAGE_MAPPING.md) - Package translation reference

### Community Support

1. **GitHub Issues:**
   - Report bugs: https://github.com/yourusername/linmigrator/issues
   - Search existing issues first
   - Provide logs and error messages

2. **Fedora Community:**
   - Fedora Forums: https://discussion.fedoraproject.org/
   - Fedora Subreddit: r/Fedora
   - Fedora IRC: #fedora on Libera.Chat

3. **General Linux Help:**
   - Ask Ubuntu: https://askubuntu.com/ (for export issues)
   - Unix StackExchange: https://unix.stackexchange.com/
   - r/linuxquestions on Reddit

### Logs and Debugging

**Export logs:**
```bash
# Export script outputs to terminal
# Redirect to file:
sudo ./scripts/export.sh 2>&1 | tee export.log
```

**Import logs:**
```bash
# Import script outputs to terminal
# Redirect to file:
sudo ./scripts/import.sh 2>&1 | tee import.log
```

**Ansible logs:**
```bash
# Ansible output in terminal during import
# Or run manually with verbose:
cd ansible
ansible-playbook -i inventory/local bootstrap.yml -vvv
```

**System logs:**
```bash
# View system messages
journalctl -xe

# View boot messages
journalctl -b

# View specific service
journalctl -u <service-name>
```

### What to Include in Bug Reports

When asking for help or reporting issues, provide:

1. **System info:**
   ```bash
   # Ubuntu (export system)
   lsb_release -a
   
   # Fedora (import system)
   cat /etc/os-release
   ```

2. **Script version:**
   ```bash
   git log --oneline -1
   ```

3. **Error messages:**
   - Copy exact error text
   - Include surrounding context
   - Provide full log if possible

4. **Steps to reproduce:**
   - What you did
   - What you expected
   - What actually happened

5. **Configuration:**
   - Export settings used
   - Import customizations made
   - Any manual modifications

---

## Quick Fixes Checklist

Before diving into detailed troubleshooting:

- [ ] Reboot the system
- [ ] Check internet connection
- [ ] Verify you're running with `sudo`
- [ ] Update DNF cache: `sudo dnf clean all && sudo dnf makecache`
- [ ] Check disk space: `df -h`
- [ ] Verify all files copied from Ubuntu to Fedora
- [ ] Confirm encryption key file exists and is correct
- [ ] Check SELinux isn't blocking: `sudo setenforce 0` (temporary test)
- [ ] Look for typos in configuration files
- [ ] Review script output for specific error messages

---

**Last Updated:** LinMigrator v2.0 - Export/Import Architecture

For the latest documentation, visit: https://github.com/yourusername/linmigrator
