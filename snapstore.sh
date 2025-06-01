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

del_snap(){
if [ ! -d /mnt/btrfs/@_backup ]; then
    if mount | grep -q /mnt/btrfs/@_backup; then
       sudo umount /mnt/btrfs/@_backup
    fi
    sudo btrfs subvolume delete /mnt/btrfs/@_backup
fi
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


#!/bin/bash

pause() {
    echo
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

while true; do
    clear
    echo "==============================="
    echo "       SnapStore BTRFS         "
    echo "==============================="
    echo "1. SnapShoot"
    echo "2. Restore"
    echo "0. Exit"
    echo "==============================="
    read -p "Silahkan input pilihan Menu anda : " pilmen

    case "$pilmen" in
        1)
            echo "1.Snapshoot to internal"
            echo "2.Snapshoot to file"
            echo "3.Snapshoot to file+Compress"
            read -p "Silahkan input pilihan SubMenu anda : " pilsub
            case "$pilsub" in
            1)
            mount_btrfs
            del_snap
            sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
            umount /mnt/btrfs
            ;;
            2)
            mount_btrfs
            sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
            sudo btrfs send /mnt/btrfs/@_backup > btrfs-backup.img
            del_snap
            umount /mnt/btrfs
            ;;
            3)
            mount_btrfs
            sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
            sudo btrfs send /mnt/btrfs/@_backup | gzip -c > btrfs-backup.img.gz
            del_snap
            umount /mnt/btrfs
            ;;
            pause
            ;;
        2)
            echo "[+] Opsi 2: SnapShoot"
            # Tambahkan script snapshot di sini
            pause
            ;;
  
        0)
            echo "Keluar dari program.."
            exit 0
            ;;
        *)
            echo "Input salah/tidak diketahui!"
            pause
            ;;
    esac
done
