#!/bin/bash
#snapshoot
sudo mkdir -p /mnt/snap
sudo mount -o subvolid=5 /dev/vda1 /mnt/snap
sudo btrfs subvolume snapshot -r /mnt/snap/@ /mnt/snap/@_clean
umount /mnt/snap
rm -rf /mnt/snap

#!/bin/bash
#restore
sudo mkdir -p /mnt/res
sudo mount -o subvolid=5 /dev/vda1 /mnt/res
sudo btrfs subvolume delete /mnt/res/@
sudo btrfs subvolume snapshot /mnt/res/@clean /mnt/res/@
sudo umount /mnt/res
sudo rm -rf /mnt/res
reboot
