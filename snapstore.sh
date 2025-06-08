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

get_valid_path() {
    local prompt="$1"
    local varname="$2"

    while true; do
        echo
        read -p "$prompt" input
        if [[ "$input" =~ ^/dev/[^/]+/.+ ]]; then
            eval "$varname=\"$input\""
            break
        else
            echo "❌ Format input salah. Contoh yang benar: /dev/sda1/home/"
        fi
    done
}

save_file_btrfs() {
    local MODE="$1"  # boleh kosong atau 'gzip'
    local TARGET_PATH="$2"

    DEV=$(echo "$TARGET_PATH" | cut -d'/' -f3)
    SUBDIR=$(echo "$TARGET_PATH" | cut -d'/' -f4-)
    MOUNTPOINT="/mnt/$DEV"
    DEST_DIR="$MOUNTPOINT/$SUBDIR"

    if [ "$MODE" == "gzip" ]; then
        FILE_NAME="btrfs-backup.img.gz"
    else
        FILE_NAME="btrfs-backup.img"
    fi
    FILE_PATH="$DEST_DIR/$FILE_NAME"

    echo "🔧 Menyiapkan mount point $MOUNTPOINT"
    sudo mkdir -p "$MOUNTPOINT"

    echo "📦 Mounting /dev/$DEV ke $MOUNTPOINT..."
    if auto_mount_target "/dev/$DEV" "$MOUNTPOINT"; then
        echo "✅ Berhasil mount /dev/$DEV"

        if [ ! -d "$DEST_DIR" ]; then
            echo "📁 Membuat direktori tujuan: $DEST_DIR"
            sudo mkdir -p "$DEST_DIR"
        fi

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
    local SOURCE_PATH="$2"

    DEV=$(echo "$SOURCE_PATH" | cut -d'/' -f3)
    SUBPATH=$(echo "$SOURCE_PATH" | cut -d'/' -f4-)
    FILE_NAME=$(basename "$SOURCE_PATH")
    MOUNTPOINT="/mnt/$DEV"
    FILE_PATH="$MOUNTPOINT/$(dirname "$SUBPATH")/$FILE_NAME"

    echo "🔧 Menyiapkan mount point $MOUNTPOINT"
    sudo mkdir -p "$MOUNTPOINT"

    echo "📦 Mounting /dev/$DEV ke $MOUNTPOINT..."
    if auto_mount_target "/dev/$DEV" "$MOUNTPOINT"; then
        echo "✅ Berhasil mount /dev/$DEV"

        if [ ! -f "$FILE_PATH" ]; then
            echo "❌ File backup tidak ditemukan di $FILE_PATH"
            sudo umount "$MOUNTPOINT"
            return 2
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
        sudo umount "$MOUNTPOINT"
        echo "✅ Restore selesai!"
    else
        echo "❌ Gagal mount /dev/$DEV"
        return 3
    fi
}

mount_btrfs() {
    local SUBVOLID="$1"
    local MOUNTPOINT="$2"

    if [ -z "$SUBVOLID" ] || [ -z "$MOUNTPOINT" ]; then
        echo "❌ Penggunaan: moun
