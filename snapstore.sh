#!/bin/bash

save_file_btrfs() {
    local MODE="$1"  # boleh kosong atau 'gzip'

    echo
    read -p "Silahkan masukkan folder tujuan [contoh: /dev/sda1/home/]: " TARGET_PATH

    if [[ ! "$TARGET_PATH" =~ ^/dev/[^/]+/.+ ]]; then
        echo "❌ Format input salah. Contoh yang benar: /dev/sda1/home/"
        return 1
    fi

    DEV=$(echo "$TARGET_PATH" | cut -d'/' -f3)
    SUBDIR=$(echo "$TARGET_PATH" | cut -d'/' -f4-)

    MOUNTPOINT="/mnt/$DEV"
    DEST_DIR="$MOUNTPOINT/$SUBDIR"

    FILE_NAME="btrfs-backup.img"
    [ "$MODE" == "gzip" ] && FILE_NAME="btrfs-backup.img.gz"

    FILE_PATH="$DEST_DIR/$FILE_NAME"

    echo "🔧 Menyiapkan mount point $MOUNTPOINT"
    sudo mkdir -p "$MOUNTPOINT"

    echo "📦 Mounting /dev/$DEV ke $MOUNTPOINT..."
    if sudo mount "/dev/$DEV" "$MOUNTPOINT"; then
        echo "✅ Berhasil mount /dev/$DEV"

        [ ! -d "$DEST_DIR" ] && sudo mkdir -p "$DEST_DIR"

        if [ ! -e /mnt/btrfs/@_backup ]; then
            echo "❌ Source snapshot /mnt/btrfs/@_backup tidak ditemukan!"
            sudo umount "$MOUNTPOINT"
            return 2
        fi

        echo "📝 Menyimpan $FILE_NAME ke $FILE_PATH"
        if [ "$MODE" == "gzip" ]; then
            sudo btrfs send /mnt/btrfs/@_backup | gzip -c > "$FILE_PATH"
        else
            sudo btrfs send /mnt/btrfs/@_backup > "$FILE_PATH"
        fi

        echo "💾 File berhasil disimpan!"
        sudo umount "$MOUNTPOINT"
        echo "✅ Selesai!"
    else
        echo "❌ Gagal mount /dev/$DEV"
        return 3
    fi
}

restore_file_btrfs() {
    local MODE="$1"  # kosong atau 'gzip'

    echo
    read -p "Silahkan masukkan folder asal backup [contoh: /dev/sda1/home/]: " SOURCE_PATH

    if [[ ! "$SOURCE_PATH" =~ ^/dev/[^/]+/.+ ]]; then
        echo "❌ Format input salah. Contoh yang benar: /dev/sda1/home/"
        return 1
    fi

    DEV=$(echo "$SOURCE_PATH" | cut -d'/' -f3)
    SUBDIR=$(echo "$SOURCE_PATH" | cut -d'/' -f4-)

    MOUNTPOINT="/mnt/$DEV"
    SOURCE_DIR="$MOUNTPOINT/$SUBDIR"

    FILE_NAME="btrfs-backup.img"
    [ "$MODE" == "gzip" ] && FILE_NAME="btrfs-backup.img.gz"

    FILE_PATH="$SOURCE_DIR/$FILE_NAME"

    echo "📦 Mounting /dev/$DEV ke $MOUNTPOINT..."
    sudo mkdir -p "$MOUNTPOINT"
    if sudo mount "/dev/$DEV" "$MOUNTPOINT"; then
        echo "✅ Berhasil mount /dev/$DEV"

        if [ ! -f "$FILE_PATH" ]; then
            echo "❌ File $FILE_PATH tidak ditemukan!"
            sudo umount "$MOUNTPOINT"
            return 2
        fi

        mount_btrfs 0 /mnt/btrfs
        del_snap
        echo "♻️  Melakukan restore dari $FILE_NAME"

        if [ "$MODE" == "gzip" ]; then
            gunzip -c "$FILE_PATH" | sudo btrfs receive /mnt/btrfs
        else
            sudo btrfs receive /mnt/btrfs < "$FILE_PATH"
        fi

        echo "✅ Restore selesai."
        sudo umount /mnt/btrfs
        sudo umount "$MOUNTPOINT"
        sync
        pause
    else
        echo "❌ Gagal mount /dev/$DEV"
        return 3
    fi
}

mount_btrfs() {
    local SUBVOLID="$1"
    local MOUNTPOINT="$2"

    [ -z "$SUBVOLID" ] || [ -z "$MOUNTPOINT" ] && {
        echo "❌ Penggunaan: mount_btrfs <subvolid> <mountpoint>"
        return 1
    }

    sudo mkdir -p "$MOUNTPOINT"

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvolid=$SUBVOLID ke $MOUNTPOINT"
        if sudo mount -o subvolid="$SUBVOLID" "$DEV" "$MOUNTPOINT" 2>/dev/null; then
            echo "✅  Berhasil mount $DEV ke $MOUNTPOINT"
            return 0
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

# MENU UTAMA
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
                        echo "🗑️ Menghapus @ lama..."
                        sudo btrfs subvolume delete /mnt/btrfs/@
                        echo "♻️ Mengembalikan @_backup ke @..."
                        sudo btrfs subvolume snapshot /mnt/btrfs/@_backup /mnt/btrfs/@
                        del_snap
                    else
                        echo "❌ Tidak ditemukan /mnt/btrfs/@_backup"
                    fi
                    sudo umount /mnt/btrfs
                    sync
                    pause
                    ;;
                2)
                    restore_file_btrfs
                    ;;
                3)
                    restore_file_btrfs gzip
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
