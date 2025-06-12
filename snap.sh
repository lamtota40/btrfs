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
sudo umount /mnt/snap
sudo rm -rf /mnt/snap

#!/bin/bash
#restore
sudo mkdir -p /mnt/res
sudo mount -o subvolid=5 /dev/vda1 /mnt/res
sudo btrfs subvolume delete /mnt/res/@
sudo btrfs subvolume snapshot /mnt/res/@clean /mnt/res/@
sudo umount /mnt/res
sudo rm -rf /mnt/res
sudo reboot



#etc
sudo apt install software-properties-common nano
sudo grub-reboot 'Grml Rescue System (grml-small-2024.12-amd64.iso)'
