#!/bin/bash

sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=5 /dev/vda1 /mnt/btrfs
sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_clean
umount /mnt/btrfs
rm -rf /mnt/btrfs
