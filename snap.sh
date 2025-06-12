#!/bin/bash

sudo mkdir /mnt/vda1
sudo mount -o subvol=@ /dev/vda1 /mnt/vda1
sudo mount --bind /dev /mnt/vda1/dev
sudo mount --bind /proc /mnt/vda1/proc
sudo mount --bind /sys /mnt/vda1/sys
chroot /mnt/vda1 /bin/bash -c "
grub-editenv /boot/grub/grubenv list
grub-editenv /boot/grub/grubenv unset next_entry
update-grub
"
umount /mnt/vda1/dev /mnt/vda1/proc /mnt/vda1/sys
umount /mnt/vda1
rm -rf /mnt/vda1

#snapshoot
sudo mkdir -p /mnt/snap
sudo mount -o subvolid=5 /dev/vda1 /mnt/snap
sudo btrfs subvolume list /mnt/snap
sudo btrfs subvolume snapshot -r /mnt/snap/@ /mnt/snap/@_clean
sudo btrfs subvolume list /mnt/snap
sudo umount /mnt/snap
sudo rm -rf /mnt/snap
sudo reboot
