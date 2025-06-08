#!/bin/bash

auto_mount_target() {
    local DEV="$1"
    local MOUNTPOINT="$2"

    FS_TYPE=$(lsblk -no FSTYPE "$DEV")

    if [ "$FS_TYPE" = "btrfs" ]; then
        sudo mount -o subvolid=0 "$DEV" "$MOUNTPOINT"
    else
        sudo mount "$DEV" "$MOUNTPOINT"
    fi
}

save_file_btrfs() {
    local MODE="$1"  # boleh kosong atau 'gzip'

    echo
    read -p "Silahkan masukkan folder tujuan lengkap (contoh: /mnt/usb): " DEST_DIR

    if [ ! -d "$DEST_DIR" ]; then
        echo "❌ Folder tujuan tidak ditemukan: $DEST_DIR"
        return 1
    fi

    if [ "$MODE" == "gzip" ]; then
        FILE_NAME="btrfs-backup.img.gz"
    else
        FILE_NAME="btrfs-backup.img"
    fi
    FILE_PATH="$DEST_DIR/$FILE_NAME"

    if [ ! -e /mnt/btrfs/@_backup ]; then
        echo "❌ Source snapshot /mnt/btrfs/@_backup tidak ditemukan!"
        return 2
    fi

    echo "📝 Menyimpan $FILE_NAME ke $FILE_PATH"
    if [ "$MODE" == "gzip" ]; then
        sudo btrfs send /mnt/btrfs/@_backup | gzip -c > "$FILE_PATH"
    else
        sudo btrfs send /mnt/btrfs/@_backup > "$FILE_PATH"
    fi

    echo "💾 File berhasil disimpan!"
    echo "✅ Selesai!"
}

restore_file_btrfs() {
    local MODE="$1"  # kosong atau 'gzip'

    echo
    read -p "Silahkan masukkan lokasi file backup lengkap (contoh: /mnt/usb/btrfs-backup.img): " FILE_PATH

    if [ ! -f "$FILE_PATH" ]; then
        echo "❌ File backup tidak ditemukan di: $FILE_PATH"
        return 1
    fi

    mount_btrfs 0 /mnt/btrfs
    del_snap

    echo "🔄 Melakukan restore dari $FILE_PATH"
    if [ "$MODE" == "gzip" ]; then
        gzip -dc "$FILE_PATH" | sudo btrfs receive /mnt/btrfs
    else
        sudo btrfs receive /mnt/btrfs < "$FILE_PATH"
    fi

    sudo umount /mnt/btrfs
    echo "✅ Restore selesai!"
}

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
                    save_file_btrfs
                    del_snap
                    sudo umount /mnt/btrfs
                    pause
                    ;;
                3)
                    mount_btrfs 0 /mnt/btrfs
                    del_snap
                    sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
                    save_file_btrfs gzip
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
                    mount_btrfs 0 /mnt/btrfs
                    if [ -d /mnt/btrfs/@_backup ]; then
                        echo "🗑️ Menghapus subvolume @..."
                        sudo btrfs subvolume delete /mnt/btrfs/@
                        echo "♻️ Memindahkan @_backup ke @..."
                        sudo btrfs subvolume snapshot /mnt/btrfs/@_backup /mnt/btrfs/@
                        del_snap
                    else
                        echo "❌ Gagal restore: /mnt/btrfs/@_backup tidak ditemukan"
                    fi
                    sudo umount /mnt/btrfs
                    sync
                    pause
                    ;;
                2)
                    restore_file_btrfs
                    sync
                    pause
                    ;;
                3)
                    restore_file_btrfs gzip
                    sync
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
