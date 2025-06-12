#!/bin/bash

sudo mkdir -p /mnt/res
sudo mount -o subvolid=5 /dev/vda1 /mnt/res
sudo btrfs subvolume list /mnt/res
sudo btrfs subvolume delete /mnt/res/@
sudo btrfs subvolume snapshot /mnt/res/@_clean /mnt/res/@
sudo btrfs subvolume list /mnt/res
sudo umount /mnt/res
sudo rm -rf /mnt/res
sync
sudo reboot
