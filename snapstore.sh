#!/bin/bash

mount_btrfs() {
    local SUBVOLID="$1"
    local MOUNTPOINT="$2"

    if [ -z "$SUBVOLID" ] || [ -z "$MOUNTPOINT" ]; then
        echo "❌ Penggunaan: mount_btrfs <subvolid> <mountpoint>"
        return 1
    fi

    sudo mkdir -p "$MOUNTPOINT"

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvolid=$SUBVOLID ke $MOUNTPOINT"
        if sudo mount -o subvolid="$SUBVOLID" "$DEV" "$MOUNTPOINT" 2>/dev/null; then
            echo "✅  Berhasil mount $DEV ke $MOUNTPOINT dengan subvolid=$SUBVOLID"
            sudo btrfs subvolume list "$MOUNTPOINT"
            return 0
        else
            echo "❌ Gagal mount $DEV"
        fi
    done

    echo "❌ Tidak ada partisi BTRFS yang berhasil di-mount."
    return 1
}

del_snap(){
    if [ -d /mnt/btrfs/@_backup ]; then
        if mount | grep -q "/mnt/btrfs/@_backup"; then
            echo "⚠️ Snapshot @_backup sedang di-mount. Unmounting..."
            sudo umount /mnt/btrfs/@_backup
        fi
        echo "🗑️ Menghapus snapshot @_backup..."
        sudo btrfs subvolume delete /mnt/btrfs/@_backup
    fi
}

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
            echo "1. Snapshoot to internal"
            echo "2. Snapshoot to file"
            echo "3. Snapshoot to file + Compress"
            read -p "Silahkan input pilihan SubMenu anda : " pilsub1
            case "$pilsub1" in
                1)
                    mount_btrfs 0 /mnt/btrfs
                    del_snap
                    sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
                    sudo umount /mnt/btrfs
                    pause
                    ;;
                2)
                    mount_btrfs 0 /mnt/btrfs
                    del_snap
                    sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
                    sudo btrfs send /mnt/btrfs/@_backup > btrfs-backup.img
                    del_snap
                    sudo umount /mnt/btrfs
                    pause
                    ;;
                3)
                    mount_btrfs 0 /mnt/btrfs
                    del_snap
                    sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
                    sudo btrfs send /mnt/btrfs/@_backup | gzip -c > btrfs-backup.img.gz
                    del_snap
                    sudo umount /mnt/btrfs
                    pause
                    ;;
                *)
                    echo "Input SubMenu tidak valid"
                    pause
                    ;;
            esac
            ;;
        2)
            echo "1. Restore from internal"
            echo "2. Restore from file"
            echo "3. Restore from file + Compress"
            read -p "Silahkan input pilihan SubMenu anda : " pilsub2
            case "$pilsub2" in
                1)
                    mount_btrfs 0 /mnt/restore
                    echo "🗑️ Menghapus subvolume lama @..."
                    sudo btrfs subvolume delete /mnt/restore/@
                    echo "♻️ Membuat snapshot baru dari @_backup ke @..."
                    sudo btrfs subvolume snapshot /mnt/restore/@_backup /mnt/restore/@
                    sudo umount /mnt/restore
                    sync
                    pause
                    ;;
                2)
                    echo "❗ Belum diimplementasikan"
                    pause
                    ;;
                3)
                    echo "❗ Belum diimplementasikan"
                    pause
                    ;;
                *)
                    echo "Input salah/tidak diketahui!"
                    pause
                    ;;
            esac
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
