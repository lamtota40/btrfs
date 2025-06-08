#!/bin/bash

# Fungsi untuk mount BTRFS dengan parameter subvolid dan target mount point
mount_btrfs() {
    local SUBVOLID="$1"
    local TARGET="$2"
    
    # Deteksi otomatis device BTRFS pertama
    local DEFAULT_DEV
    DEFAULT_DEV=$(lsblk -o NAME,FSTYPE -rn | awk '$2 == "btrfs" {print "/dev/" $1; exit}')

    if [[ -z "$DEFAULT_DEV" ]]; then
        echo "❌  Tidak ditemukan device dengan sistem file BTRFS"
        return 1
    fi

    read -e -i "$DEFAULT_DEV" -p "📌  Lokasi BTRFS (edit jika tidak sesuai): " BTRFS_DEV

    sudo mkdir -p "$TARGET"
    sudo mount -o subvolid="$SUBVOLID" "$BTRFS_DEV" "$TARGET"
    echo "✅ Berhasil mount subvolid=$SUBVOLID $BTRFS_DEV ke folder $TARGET"
}

sudo mkdir -p /mnt/btrfs
mount_btrfs 0 /mnt/btrfs

if [[ ! -d /mnt/btrfs/@ ]]; then
    echo "❌ Subvolume '@' tidak ditemukan di /mnt/btrfs"
    exit 1
fi
sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup

umount /mnt/btrfs
rm -rf /mnt/btrfs

# Snapshoot
#internal
sudo mkdir -p /mnt/btrfs_root
sudo mount -o subvolid=5 /dev/sda1 /mnt/btrfs_root
sudo btrfs subvolume snapshot -r /mnt/btrfs_root/@ /mnt/btrfs_root/@_clean

#eksternal
sudo mkdir -p /mnt/btrfs
sudo mount -o subvolid=0 /dev/sda1 /mnt/btrfs
sudo btrfs subvolume snapshot -r /mnt/btrfs/@ /mnt/btrfs/@_backup
sudo btrfs send /mnt/btrfs/@_backup | gzip -c > btrfs-backup.img.gz
#backup tanpa kompresi
sudo btrfs send /mnt/btrfs/@_backup > btrfs-backup.img
#backup ke partisi lain misal /dev/sda2
sudo btrfs send /mnt/btrfs/@_backup > /mnt/sda2/btrfs-sda1-backup.img
sudo btrfs send /mnt/btrfs/@_backup | gzip -c > /mnt/sda2/btrfs-sda1-backup.img.gz


#restore dari GRML
#!/bin/bash

mount -o subvolid=5 /dev/sda1 /mnt
cd /mnt
btrfs subvolume delete @
btrfs subvolume delete @home
btrfs subvolume snapshot @clean @
btrfs subvolume snapshot @home_clean @home
sync
reboot
