# Snapshoot
sudo mkdir -p /mnt/btrfs_root
sudo mount -o subvolid=5 /dev/sda1 /mnt/btrfs_root
cd /mnt/btrfs_root
sudo btrfs subvolume snapshot -r @ @clean
sudo btrfs subvolume snapshot -r @home @home_clean
cd

#restore dari GRML
#!/bin/bash

mount -o subvolid=5 /dev/sda1 /mnt
cd /mnt
btrfs subvolume delete @
btrfs subvolume delete @home
btrfs subvolume snapshot @clean @
btrfs subvolume snapshot @home_clean @home
sync
reboot
