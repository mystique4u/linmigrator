#!/usr/bin/env python3
"""
Ubuntu System Inventory Gatherer
Scans mounted Ubuntu disks to collect package and configuration information
"""

import os
import sys
import json
import argparse
import subprocess
import re
from pathlib import Path
from typing import Dict, List, Set, Optional


class UbuntuInventoryGatherer:
    """Gathers system information from mounted Ubuntu filesystems"""
    
    def __init__(self, root_mount: str, home_mount: str):
        self.root_mount = Path(root_mount)
        self.home_mount = Path(home_mount)
        self.inventory = {
            "packages": {
                "apt": [],
                "snap": [],
                "flatpak": []
            },
            "services": [],
            "users": [],
            "groups": [],
            "configs": {},
            "statistics": {}
        }
    
    def gather_all(self) -> Dict:
        """Run all gathering methods"""
        print("🔍 Gathering Ubuntu system inventory...")
        
        self.gather_apt_packages()
        self.gather_snap_packages()
        self.gather_flatpak_packages()
        self.gather_systemd_services()
        self.gather_users_and_groups()
        self.gather_config_info()
        self.gather_statistics()
        
        print("✅ Inventory gathering complete!")
        return self.inventory
    
    def gather_apt_packages(self):
        """Extract installed APT packages from dpkg status"""
        print("  📦 Gathering APT packages...")
        
        dpkg_status = self.root_mount / "lib" / "dpkg" / "status"
        if not dpkg_status.exists():
            print(f"    ⚠️  Warning: {dpkg_status} not found")
            return
        
        try:
            with open(dpkg_status, 'r') as f:
                content = f.read()
            
            # Parse dpkg status file
            packages = []
            current_package = {}
            
            for line in content.split('\n'):
                if line.startswith('Package: '):
                    if current_package.get('status') == 'install ok installed':
                        packages.append({
                            'name': current_package.get('name'),
                            'version': current_package.get('version'),
                            'architecture': current_package.get('architecture')
                        })
                    current_package = {'name': line.split('Package: ')[1].strip()}
                
                elif line.startswith('Status: '):
                    current_package['status'] = line.split('Status: ')[1].strip()
                
                elif line.startswith('Version: '):
                    current_package['version'] = line.split('Version: ')[1].strip()
                
                elif line.startswith('Architecture: '):
                    current_package['architecture'] = line.split('Architecture: ')[1].strip()
            
            # Add last package if exists
            if current_package.get('status') == 'install ok installed':
                packages.append({
                    'name': current_package.get('name'),
                    'version': current_package.get('version'),
                    'architecture': current_package.get('architecture')
                })
            
            self.inventory['packages']['apt'] = packages
            print(f"    ✓ Found {len(packages)} APT packages")
            
        except Exception as e:
            print(f"    ⚠️  Error reading dpkg status: {e}")
    
    def gather_snap_packages(self):
        """Extract installed Snap packages"""
        print("  📦 Gathering Snap packages...")
        
        snap_dir = self.root_mount / "snap"
        if not snap_dir.exists():
            print("    ℹ️  No Snap directory found")
            return
        
        try:
            snaps = []
            for snap_path in snap_dir.iterdir():
                if snap_path.is_dir() and snap_path.name not in ['bin', 'README']:
                    # Get current version link
                    current_link = snap_path / "current"
                    version = None
                    if current_link.exists() and current_link.is_symlink():
                        version = os.readlink(current_link)
                    
                    snaps.append({
                        'name': snap_path.name,
                        'version': version
                    })
            
            self.inventory['packages']['snap'] = snaps
            print(f"    ✓ Found {len(snaps)} Snap packages")
            
        except Exception as e:
            print(f"    ⚠️  Error reading Snap packages: {e}")
    
    def gather_flatpak_packages(self):
        """Extract installed Flatpak packages"""
        print("  📦 Gathering Flatpak packages...")
        
        flatpak_dir = self.root_mount / "lib" / "flatpak" / "app"
        if not flatpak_dir.exists():
            # Try user flatpak directory
            flatpak_dir = self.home_mount / ".local" / "share" / "flatpak" / "app"
            if not flatpak_dir.exists():
                print("    ℹ️  No Flatpak directory found")
                return
        
        try:
            flatpaks = []
            for app_path in flatpak_dir.iterdir():
                if app_path.is_dir():
                    flatpaks.append({'name': app_path.name})
            
            self.inventory['packages']['flatpak'] = flatpaks
            print(f"    ✓ Found {len(flatpaks)} Flatpak packages")
            
        except Exception as e:
            print(f"    ⚠️  Error reading Flatpak packages: {e}")
    
    def gather_systemd_services(self):
        """Extract enabled systemd services"""
        print("  ⚙️  Gathering systemd services...")
        
        systemd_dir = self.root_mount / "etc" / "systemd" / "system"
        if not systemd_dir.exists():
            print(f"    ⚠️  Warning: {systemd_dir} not found")
            return
        
        try:
            services = []
            
            # Check multi-user.target.wants
            wants_dir = systemd_dir / "multi-user.target.wants"
            if wants_dir.exists():
                for service_link in wants_dir.iterdir():
                    if service_link.is_symlink():
                        services.append({
                            'name': service_link.name,
                            'enabled': True,
                            'target': 'multi-user.target'
                        })
            
            # Check graphical.target.wants
            graphical_wants = systemd_dir / "graphical.target.wants"
            if graphical_wants.exists():
                for service_link in graphical_wants.iterdir():
                    if service_link.is_symlink():
                        service_name = service_link.name
                        if not any(s['name'] == service_name for s in services):
                            services.append({
                                'name': service_name,
                                'enabled': True,
                                'target': 'graphical.target'
                            })
            
            self.inventory['services'] = services
            print(f"    ✓ Found {len(services)} enabled services")
            
        except Exception as e:
            print(f"    ⚠️  Error reading systemd services: {e}")
    
    def gather_users_and_groups(self):
        """Extract user and group information"""
        print("  👥 Gathering users and groups...")
        
        passwd_file = self.root_mount / "etc" / "passwd"
        group_file = self.root_mount / "etc" / "group"
        
        # Gather users
        if passwd_file.exists():
            try:
                users = []
                with open(passwd_file, 'r') as f:
                    for line in f:
                        if line.strip() and not line.startswith('#'):
                            parts = line.strip().split(':')
                            if len(parts) >= 7:
                                uid = int(parts[2])
                                # Only include regular users (UID >= 1000) and some system users
                                if uid >= 1000 or parts[0] in ['root']:
                                    users.append({
                                        'name': parts[0],
                                        'uid': uid,
                                        'gid': int(parts[3]),
                                        'home': parts[5],
                                        'shell': parts[6]
                                    })
                
                self.inventory['users'] = users
                print(f"    ✓ Found {len(users)} users")
            
            except Exception as e:
                print(f"    ⚠️  Error reading passwd: {e}")
        
        # Gather groups
        if group_file.exists():
            try:
                groups = []
                with open(group_file, 'r') as f:
                    for line in f:
                        if line.strip() and not line.startswith('#'):
                            parts = line.strip().split(':')
                            if len(parts) >= 4:
                                gid = int(parts[2])
                                if gid >= 1000 or parts[0] in ['root', 'wheel', 'sudo', 'docker']:
                                    groups.append({
                                        'name': parts[0],
                                        'gid': gid,
                                        'members': parts[3].split(',') if parts[3] else []
                                    })
                
                self.inventory['groups'] = groups
                print(f"    ✓ Found {len(groups)} groups")
            
            except Exception as e:
                print(f"    ⚠️  Error reading group: {e}")
    
    def gather_config_info(self):
        """Gather important configuration information"""
        print("  ⚙️  Gathering configuration info...")
        
        configs = {}
        
        # Network configuration
        netplan_dir = self.root_mount / "etc" / "netplan"
        if netplan_dir.exists():
            configs['has_netplan'] = True
        
        # Docker configuration
        docker_dir = self.root_mount / "etc" / "docker"
        if docker_dir.exists():
            configs['has_docker'] = True
        
        # Cron jobs
        cron_dir = self.root_mount / "etc" / "cron.d"
        if cron_dir.exists():
            configs['has_cron_jobs'] = True
            configs['cron_files'] = [f.name for f in cron_dir.iterdir() if f.is_file()]
        
        # SSH configuration
        ssh_config = self.root_mount / "etc" / "ssh" / "sshd_config"
        if ssh_config.exists():
            configs['has_ssh_config'] = True
        
        # Firewall (ufw)
        ufw_dir = self.root_mount / "etc" / "ufw"
        if ufw_dir.exists():
            configs['has_ufw'] = True
        
        self.inventory['configs'] = configs
        print(f"    ✓ Found {len(configs)} configuration items")
    
    def gather_statistics(self):
        """Gather filesystem statistics"""
        print("  📊 Gathering statistics...")
        
        stats = {}
        
        try:
            # Calculate /var size
            var_size = self._get_dir_size(self.root_mount)
            stats['var_size_mb'] = var_size
            
            # Calculate /home size
            home_size = self._get_dir_size(self.home_mount)
            stats['home_size_mb'] = home_size
            
            # Count users
            stats['user_count'] = len(self.inventory['users'])
            
            # Count packages
            stats['apt_package_count'] = len(self.inventory['packages']['apt'])
            stats['snap_package_count'] = len(self.inventory['packages']['snap'])
            stats['flatpak_package_count'] = len(self.inventory['packages']['flatpak'])
            stats['total_package_count'] = (
                stats['apt_package_count'] + 
                stats['snap_package_count'] + 
                stats['flatpak_package_count']
            )
            
            self.inventory['statistics'] = stats
            print(f"    ✓ /var size: {var_size:.2f} MB")
            print(f"    ✓ /home size: {home_size:.2f} MB")
            print(f"    ✓ Total packages: {stats['total_package_count']}")
            
        except Exception as e:
            print(f"    ⚠️  Error gathering statistics: {e}")
    
    def _get_dir_size(self, path: Path) -> float:
        """Calculate directory size in MB"""
        total_size = 0
        try:
            for item in path.rglob('*'):
                if item.is_file() and not item.is_symlink():
                    total_size += item.stat().st_size
        except Exception as e:
            print(f"    ⚠️  Error calculating size for {path}: {e}")
        
        return total_size / (1024 * 1024)  # Convert to MB


def main():
    parser = argparse.ArgumentParser(
        description='Gather inventory from Ubuntu system for Fedora migration'
    )
    parser.add_argument(
        '--root-mount',
        required=True,
        help='Path to mounted Ubuntu /var filesystem'
    )
    parser.add_argument(
        '--home-mount',
        required=True,
        help='Path to mounted Ubuntu /home filesystem'
    )
    parser.add_argument(
        '--output',
        required=True,
        help='Output JSON file path'
    )
    
    args = parser.parse_args()
    
    # Validate mount points
    if not os.path.exists(args.root_mount):
        print(f"❌ Error: Root mount point {args.root_mount} does not exist")
        sys.exit(1)
    
    if not os.path.exists(args.home_mount):
        print(f"❌ Error: Home mount point {args.home_mount} does not exist")
        sys.exit(1)
    
    # Gather inventory
    gatherer = UbuntuInventoryGatherer(args.root_mount, args.home_mount)
    inventory = gatherer.gather_all()
    
    # Create output directory if needed
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Write output
    print(f"\n💾 Writing inventory to {args.output}...")
    with open(args.output, 'w') as f:
        json.dump(inventory, f, indent=2)
    
    print(f"✅ Inventory saved successfully!")
    print(f"\n📋 Summary:")
    print(f"   APT packages: {len(inventory['packages']['apt'])}")
    print(f"   Snap packages: {len(inventory['packages']['snap'])}")
    print(f"   Flatpak packages: {len(inventory['packages']['flatpak'])}")
    print(f"   Services: {len(inventory['services'])}")
    print(f"   Users: {len(inventory['users'])}")
    print(f"   Groups: {len(inventory['groups'])}")


if __name__ == '__main__':
    main()
