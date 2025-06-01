#!/bin/bash

mount_btrfs(){
sudo mkdir -p /mnt/btrfs

for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvol=0 ke /mnt/btrfs"
        if sudo mount -o subvol=0 "$DEV" /mnt/btrfs 2>/dev/null; then
            sudo btrfs subvolume list /mnt/btrfs
            echo "✅ Berhasil mount $DEV ke /mnt/btrfs dengan subvol=0"
            return 0
        else
            echo "❌ Gagal mount $DEV"
        fi
    done
return 1
}

mount_btrfs
sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup


sudo btrfs send /mnt/btrfs/@_backup | gzip -c > btrfs-backup.img.gz
#backup tanpa kompresi
sudo btrfs send /mnt/btrfs/@_backup > btrfs-backup.img
#backup ke partisi lain misal /dev/sda2
sudo btrfs send /mnt/btrfs/@_backup > /mnt/sda2/btrfs-sda1-backup.img
sudo btrfs send /mnt/btrfs/@_backup | gzip -c > /mnt/sda2/btrfs-sda1-backup.img.gz


echo "Silakan tekan [ENTER] untuk melanjutkan reboot atau CTRL+C untuk membatalkan..."
read
