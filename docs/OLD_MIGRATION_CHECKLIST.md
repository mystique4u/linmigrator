# Migration Checklist

Use this checklist to ensure all steps are completed correctly.

## Pre-Migration (Ubuntu System)

- [ ] **Backup critical data**
  - [ ] Database dumps
  - [ ] Application configurations
  - [ ] Documents and files
  - [ ] SSH keys (should be in /home)

- [ ] **Create VM snapshot in Proxmox**
  - [ ] Snapshot Ubuntu VM
  - [ ] Document snapshot name and date

- [ ] **Document current configuration**
  - [ ] Note installed software
  - [ ] Document custom configurations
  - [ ] List important services
  - [ ] Save cron jobs

- [ ] **Prepare disks**
  - [ ] Verify /var is on separate disk
  - [ ] Verify /home is on separate disk
  - [ ] Note disk device IDs in Proxmox

## Setup Phase

- [ ] **Fresh Fedora installation**
  - [ ] Install latest Fedora
  - [ ] Configure network
  - [ ] Create user account
  - [ ] Enable SSH
  - [ ] Test SSH connectivity

- [ ] **Prepare control machine**
  - [ ] Install Ansible
  - [ ] Install Git
  - [ ] Clone linmigrator repository
  - [ ] Install Python 3

- [ ] **Run quick start**
  ```bash
  cd linmigrator
  ./scripts/quick_start.sh
  ```
  - [ ] Enter Fedora IP address
  - [ ] Configure disk devices
  - [ ] Complete bootstrap

## Inventory Gathering

- [ ] **Attach Ubuntu disks temporarily** (to a system for scanning)
  - [ ] Attach /var disk
  - [ ] Attach /home disk

- [ ] **Mount Ubuntu disks**
  ```bash
  sudo mkdir -p /mnt/ubuntu-var /mnt/ubuntu-home
  sudo mount /dev/sdX1 /mnt/ubuntu-var
  sudo mount /dev/sdY1 /mnt/ubuntu-home
  ```
  - [ ] Verify mounts: `df -h`

- [ ] **Run inventory script**
  ```bash
  sudo python3 scripts/gather_inventory.py \
    --root-mount /mnt/ubuntu-var \
    --home-mount /mnt/ubuntu-home \
    --output inventory/ubuntu_system.json
  ```
  - [ ] Review generated inventory file
  - [ ] Check package count looks reasonable

- [ ] **Unmount Ubuntu disks**
  ```bash
  sudo umount /mnt/ubuntu-var
  sudo umount /mnt/ubuntu-home
  ```

## Disk Attachment

- [ ] **In Proxmox, attach disks to Fedora VM**
  - [ ] Navigate to Fedora VM in Proxmox
  - [ ] Hardware → Add → Hard Disk
  - [ ] Select "Use existing disk"
  - [ ] Attach /var disk (note device: /dev/sdb1)
  - [ ] Attach /home disk (note device: /dev/sdc1)
  - [ ] Update group_vars/fedora_target.yml with correct devices

- [ ] **Boot Fedora and verify disks**
  ```bash
  ssh user@fedora-ip
  lsblk
  # Verify you see both disks
  ```

## Configuration Review

- [ ] **Review inventory file**
  - [ ] `cat inventory/hosts.ini`
  - [ ] Verify target IP and username

- [ ] **Review group_vars**
  - [ ] `cat group_vars/fedora_target.yml`
  - [ ] Verify disk device paths
  - [ ] Verify feature flags (developer_tools, nvidia, theme)
  - [ ] Adjust theme variant if needed

- [ ] **Review generated inventory**
  - [ ] `cat inventory/ubuntu_system.json`
  - [ ] Check package list
  - [ ] Verify user accounts

## Pre-Flight Test

- [ ] **Test Ansible connectivity**
  ```bash
  ansible -i inventory/hosts.ini fedora_target -m ping
  ```
  - [ ] Should return "pong"

- [ ] **Run playbook in check mode (dry run)**
  ```bash
  ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --check
  ```
  - [ ] Review what would be changed
  - [ ] Check for any errors

- [ ] **Create Fedora snapshot in Proxmox**
  - [ ] Snapshot Fedora VM before migration
  - [ ] Document snapshot name

## Migration Execution

- [ ] **Run the migration playbook**
  ```bash
  ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
  ```
  - [ ] Watch output for errors
  - [ ] Note any warnings
  - [ ] Save log output

- [ ] **Review migration output**
  - [ ] Check summary at end
  - [ ] Note any failed tasks
  - [ ] Review logs if needed

## Post-Migration Validation

- [ ] **Check disk mounts**
  ```bash
  ssh user@fedora-ip
  df -h
  # Verify /var and /home are mounted
  ```

- [ ] **Verify /etc/fstab**
  ```bash
  cat /etc/fstab
  # Check entries for /var and /home
  ```

- [ ] **Test NVIDIA (if installed)**
  ```bash
  nvidia-smi
  nvcc --version
  ```

- [ ] **Check critical services**
  ```bash
  systemctl status sshd
  systemctl status firewalld
  systemctl status docker  # if using
  ```

- [ ] **Verify user data**
  ```bash
  ls -la /home/
  # Check your home directory exists
  ```

- [ ] **Test SSH keys**
  - [ ] Try SSH with your key from Ubuntu
  - [ ] Verify .ssh permissions

- [ ] **Check installed packages**
  ```bash
  dnf list installed | wc -l
  code --version  # if VSCode installed
  docker --version  # if Docker installed
  ```

## Reboot Test

- [ ] **Reboot the system**
  ```bash
  sudo reboot
  ```

- [ ] **After reboot, verify:**
  - [ ] System boots correctly
  - [ ] /var and /home are mounted
  - [ ] NVIDIA drivers loaded (nvidia-smi)
  - [ ] Services are running
  - [ ] Network connectivity works

## GNOME Desktop (if using)

- [ ] **Log into GNOME**
  - [ ] Theme is applied (WhiteSur)
  - [ ] Icons look correct
  - [ ] Dock is at bottom
  - [ ] Window buttons are on left (macOS style)

- [ ] **Check GNOME extensions**
  - [ ] Open Extensions app
  - [ ] Verify installed extensions
  - [ ] Enable any disabled extensions

- [ ] **Customize if needed**
  - [ ] Open GNOME Tweaks
  - [ ] Adjust settings as desired

## Application Testing

- [ ] **Test critical applications**
  - [ ] Open VSCode (if installed)
  - [ ] Test Docker containers (if using)
  - [ ] Test Python environment
  - [ ] Test Node.js (if using)
  - [ ] Open databases (if using)

- [ ] **Verify data accessibility**
  - [ ] Check your documents in /home
  - [ ] Verify application data in /var
  - [ ] Test SSH to remote servers

## Final Steps

- [ ] **Review migration logs**
  ```bash
  cat /var/log/migration/validation_report*.txt
  ```

- [ ] **Document any issues**
  - [ ] Note any manual fixes needed
  - [ ] Document workarounds applied

- [ ] **Update any absolute paths**
  - [ ] Check scripts for hardcoded paths
  - [ ] Update configuration files if needed

- [ ] **Clean up**
  - [ ] Remove temporary files
  - [ ] Delete old snapshots (after confirming everything works)
  - [ ] Remove Ubuntu VM (after sufficient testing period)

## Optional Enhancements

- [ ] **Configure additional software**
  - [ ] Install any missing applications
  - [ ] Configure email client
  - [ ] Set up VPN

- [ ] **Customize system**
  - [ ] Set wallpaper
  - [ ] Configure keyboard shortcuts
  - [ ] Set up additional GNOME extensions

- [ ] **Security hardening**
  - [ ] Review firewall rules
  - [ ] Configure fail2ban
  - [ ] Set up automatic backups

## Rollback Plan (if needed)

If something goes wrong:

- [ ] **Restore Fedora snapshot**
  - [ ] In Proxmox, select Fedora VM
  - [ ] Snapshots → Select snapshot → Rollback

- [ ] **Reattach disks to Ubuntu**
  - [ ] Detach from Fedora
  - [ ] Reattach to Ubuntu VM
  - [ ] Boot Ubuntu

- [ ] **Review logs to identify issues**
  - [ ] Check Ansible logs
  - [ ] Review system logs
  - [ ] Document what went wrong

## Success Criteria

Migration is successful when:

- ✅ Fedora boots normally
- ✅ /var and /home are mounted from Ubuntu disks
- ✅ All critical services are running
- ✅ User can log in with SSH keys
- ✅ NVIDIA drivers work (if applicable)
- ✅ Theme is applied correctly
- ✅ Applications are accessible
- ✅ Data is intact and accessible

## Notes Section

Use this space to record any important information during migration:

```
Date started: _____________
Date completed: ___________

Issues encountered:




Resolutions:




Custom configurations needed:




Additional packages installed:




```

---

**Remember**: Take your time, test thoroughly, and keep backups!
