# Local Migration Guide (Single Machine)

This guide is for when you're running the migration **locally on the Fedora machine itself**, rather than from a separate control machine.

## Scenario

- You have one machine running at a time (either Ubuntu or Fedora)
- You'll switch between machines by shutting one down and booting the other
- The migration will be executed **on the Fedora system itself**

## Prerequisites

- Fresh Fedora installation (running)
- Ubuntu VM (shut down) with separate /var and /home virtual disks
- Both disks detached from Ubuntu and ready to attach to Fedora
- Access to Proxmox to manage disk attachments

## Step-by-Step Process

### Phase 1: Prepare on Fedora

1. **Boot into Fedora** (Ubuntu should be shut down)

2. **Clone this repository on Fedora:**
   ```bash
   cd ~
   git clone https://github.com/mystique4u/linmigrator.git
   cd linmigrator
   ```

3. **Run the local setup script:**
   ```bash
   ./scripts/local_setup.sh
   ```
   
   This will:
   - Install Ansible on Fedora
   - Configure for local execution
   - Set up inventory for localhost
   - Test Ansible connectivity

### Phase 2: Attach Ubuntu Disks

4. **In Proxmox, attach Ubuntu disks to Fedora VM:**
   - Ensure Ubuntu VM is **shut down**
   - Go to Ubuntu VM → Hardware
   - **Detach** the /var disk (note the disk ID)
   - **Detach** the /home disk (note the disk ID)
   - Go to Fedora VM → Hardware
   - Add → Hard Disk → **Use existing disk**
   - Select the /var disk from Ubuntu
   - Add → Hard Disk → **Use existing disk**
   - Select the /home disk from Ubuntu

5. **Reboot Fedora to detect new disks**

6. **Verify disks are visible:**
   ```bash
   lsblk
   # You should see the additional disks (e.g., sdb, sdc)
   ```

### Phase 3: Gather Ubuntu Inventory

7. **Mount Ubuntu disks temporarily to scan them:**
   ```bash
   sudo mkdir -p /mnt/ubuntu-var /mnt/ubuntu-home
   sudo mount /dev/sdb1 /mnt/ubuntu-var    # Adjust device name
   sudo mount /dev/sdc1 /mnt/ubuntu-home   # Adjust device name
   ```

8. **Gather inventory from Ubuntu disks:**
   ```bash
   sudo python3 scripts/gather_inventory.py \
     --root-mount /mnt/ubuntu-var \
     --home-mount /mnt/ubuntu-home \
     --output inventory/ubuntu_system.json
   ```

9. **Review the generated inventory:**
   ```bash
   cat inventory/ubuntu_system.json
   # Check package counts, users, etc.
   ```

10. **Unmount the disks:**
    ```bash
    sudo umount /mnt/ubuntu-var
    sudo umount /mnt/ubuntu-home
    ```

### Phase 4: Configure Migration

11. **Update disk configuration:**
    ```bash
    vim group_vars/fedora_target.yml
    ```
    
    Set the correct device paths:
    ```yaml
    var_disk_device: "/dev/sdb1"    # Your /var disk
    home_disk_device: "/dev/sdc1"   # Your /home disk
    ```

12. **Review other settings in group_vars/fedora_target.yml:**
    - Enable/disable features (developer_tools, nvidia, theme, etc.)
    - Adjust theme preferences
    - Configure services

### Phase 5: Run Migration

13. **Test with dry-run first (RECOMMENDED):**
    ```bash
    sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --check
    ```
    
    Review what would be changed without actually applying.

14. **Run the actual migration:**
    ```bash
    sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
    ```
    
    **Note:** We use `sudo` because the playbook needs to:
    - Mount disks
    - Install packages
    - Configure system services
    - Modify system files

15. **Monitor the output:**
    - Watch for any errors or warnings
    - The migration can take 30-60 minutes depending on packages
    - NVIDIA driver compilation may take 5-10 minutes

### Phase 6: Post-Migration

16. **Review the migration report:**
    ```bash
    cat /var/log/migration/validation_report_*.txt
    ```

17. **Check that disks are mounted:**
    ```bash
    df -h
    # Verify /var and /home are mounted
    ```

18. **Reboot the system:**
    ```bash
    sudo reboot
    ```

19. **After reboot, verify everything:**
    ```bash
    # Check mounts
    df -h
    mount | grep -E '(/var|/home)'
    
    # Check NVIDIA (if installed)
    nvidia-smi
    
    # Check services
    systemctl --failed
    
    # Check your home directory
    ls -la ~/
    ```

20. **Log into GNOME desktop:**
    - Check that WhiteSur theme is applied
    - Verify extensions are working
    - Test applications

## Key Differences from Remote Execution

| Aspect | Local (This Guide) | Remote (Original) |
|--------|-------------------|-------------------|
| Where Ansible runs | On Fedora itself | On separate control machine |
| Inventory | `localhost` | Target IP address |
| Connection | `ansible_connection=local` | SSH |
| Command | `sudo ansible-playbook` | `ansible-playbook` |
| Setup | `./scripts/local_setup.sh` | `./scripts/bootstrap_target.sh` |

## Quick Command Reference

```bash
# Setup
./scripts/local_setup.sh

# Mount disks to scan
sudo mount /dev/sdb1 /mnt/ubuntu-var
sudo mount /dev/sdc1 /mnt/ubuntu-home

# Gather inventory
sudo python3 scripts/gather_inventory.py \
  --root-mount /mnt/ubuntu-var \
  --home-mount /mnt/ubuntu-home \
  --output inventory/ubuntu_system.json

# Unmount
sudo umount /mnt/ubuntu-var /mnt/ubuntu-home

# Dry run
sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml --check

# Actual migration
sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml

# Reboot
sudo reboot
```

## Troubleshooting Local Execution

### Issue: "Permission denied"

**Solution:** Use `sudo` when running the playbook:
```bash
sudo ansible-playbook -i inventory/hosts.ini playbooks/migrate.yml
```

### Issue: "localhost could not be reached"

**Solution:** Verify inventory configuration:
```bash
cat inventory/hosts.ini
# Should show: localhost ansible_connection=local
```

### Issue: Ansible not found

**Solution:** Install Ansible:
```bash
sudo dnf install ansible python3-pip
```

### Issue: Can't see Ubuntu disks

**Solution:**
1. Verify in Proxmox that disks are attached to Fedora VM
2. Reboot Fedora
3. Check with `lsblk`

## Advantages of Local Execution

✅ **Simpler setup** - No SSH configuration needed  
✅ **Faster** - No network overhead  
✅ **One machine** - Don't need a control machine running  
✅ **Direct access** - Easier debugging and monitoring  

## Important Notes

⚠️ **Use sudo**: The playbook needs root privileges to mount disks and install packages

⚠️ **Single machine**: Only one VM should be running at a time

⚠️ **Disk safety**: Make sure disks are properly detached from Ubuntu before attaching to Fedora

⚠️ **Backups**: Still create Proxmox snapshots before starting!

---

**You're all set!** Start with `./scripts/local_setup.sh` and follow the steps above. 🚀
