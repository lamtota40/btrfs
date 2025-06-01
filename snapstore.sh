#!/bin/bash
mount_btrfs()

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
