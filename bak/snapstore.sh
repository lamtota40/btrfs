sudo mkdir -p /mnt/btrfs

# Snapshoot
#internal
sudo mkdir -p /mnt/btrfs_root
sudo mount -o subvolid=5 /dev/sda1 /mnt/btrfs_root
sudo btrfs subvolume snapshot -r /mnt/btrfs_root/@ /mnt/btrfs_root/@_clean

#eksternal
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=0 /dev/sda1 /mnt/btrfs
sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
sudo btrfs send /mnt/btrfs/@_backup | gzip -c > btrfs-backup.img.gz
#backup tanpa kompresi
sudo btrfs send /mnt/btrfs/@_backup > btrfs-backup.img
#backup ke partisi lain misal /dev/sda2
sudo btrfs send /mnt/btrfs/@_backup > /mnt/sda2/btrfs-sda1-backup.img
sudo btrfs send /mnt/btrfs/@_backup | gzip -c > /mnt/sda2/btrfs-sda1-backup.img.gz


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
