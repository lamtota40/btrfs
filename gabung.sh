#!/bin/bash

# Fungsi: get_subvolid <subvolume_name>
get_subvolid() {
    local SUBVOL_NAME="$1"
    local DEV
    local ID

    [ -z "$SUBVOL_NAME" ] && return 1

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        mkdir -p /mnt/btrfs-top
        if mount -o subvolid=0 "$DEV" /mnt/btrfs-top 2>/dev/null; then
            ID=$(btrfs subvolume list /mnt/btrfs-top | awk -v name="$SUBVOL_NAME" '$NF == name {print $2}')
            umount /mnt/btrfs-top
            [ -n "$ID" ] && echo "$ID" && return 0
        fi
    done

    return 1
}

# Fungsi: mount_subvolid <mount_point> <subvolid>
mount_subvolid() {
    local MOUNT_POINT="$1"
    local SUBVOLID="$2"

    if [ -z "$MOUNT_POINT" ] || [ -z "$SUBVOLID" ]; then
        echo "❌ mount_subvolid membutuhkan 2 argumen: <mount_point> <subvolid>"
        return 1
    fi

    [ ! -d "$MOUNT_POINT" ] && mkdir -p "$MOUNT_POINT"

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvolid=$SUBVOLID ke $MOUNT_POINT"
        if mount -o subvolid=$SUBVOLID "$DEV" "$MOUNT_POINT" 2>/dev/null; then
            echo "✅  Berhasil mount $DEV ke $MOUNT_POINT dengan subvolid=$SUBVOLID"
            return 0
        else
            echo "❌  Gagal mount $DEV"
        fi
    done

    echo "❌ Tidak ada partisi Btrfs yang berhasil di-mount dengan subvolid=$SUBVOLID"
    return 1
}

# Cek apakah subvolume @home ada
echo "🔍 Mengecek keberadaan subvolume @home..."
ID_HOME=$(get_subvolid "@home")
if [ -z "$ID_HOME" ]; then
    echo "❌  Subvolume @home tidak ditemukan, menghentikan proses."
    exit 1
fi

# Mount rootfs (@)
ID_ROOT=$(get_subvolid "@")
mkdir -p /mnt/rootfs
mount_subvolid /mnt/rootfs "$ID_ROOT"

# Siapkan direktori home di rootfs
[ -d /mnt/rootfs/home ] && rm -rf /mnt/rootfs/home
mkdir -p /mnt/rootfs/home

# Mount home (@home)
mkdir -p /mnt/homefs
mount_subvolid /mnt/homefs "$ID_HOME"

# Tampilkan list subvolume sebelum proses
echo "📋 Subvolume SEBELUM pemindahan:"
mkdir -p /mnt/btrfs-top
for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
    if mount -o subvolid=5 "$DEV" /mnt/btrfs-top 2>/dev/null; then
        btrfs subvolume list /mnt/btrfs-top
        umount /mnt/btrfs-top
        break
    fi
done

# Pindahkan isi @home ke /home dalam @
rsync -a /mnt/homefs/ /mnt/rootfs/home/

# Bersihkan homefs
umount /mnt/homefs
rm -rf /mnt/homefs

# Backup dan edit fstab
cp /mnt/rootfs/etc/fstab /mnt/rootfs/etc/fstab.bak
sed -i '/^[^#]*[[:space:]]\/home[[:space:]]\+btrfs.*subvol=@home/d' /mnt/rootfs/etc/fstab

# Persiapan chroot
mount --bind /dev /mnt/rootfs/dev
mount --bind /proc /mnt/rootfs/proc
mount --bind /sys /mnt/rootfs/sys

# Jalankan grub di chroot
chroot /mnt/rootfs /bin/bash -c "
grub-reboot 0
grub-set-default 'Ubuntu'
update-grub
"

# Cleanup mount
umount /mnt/rootfs/dev
umount /mnt/rootfs/proc
umount /mnt/rootfs/sys

# Hapus subvolume @home dari top-level
mkdir -p /mnt/btrfs-top
for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
    if mount -o subvolid=5 "$DEV" /mnt/btrfs-top 2>/dev/null; then
        if btrfs subvolume list /mnt/btrfs-top | grep -q "@home"; then
            echo "🗑️  Menghapus subvolume @home dari $DEV"
            btrfs subvolume delete /mnt/btrfs-top/@home
        fi

        # ⬅️ Tambahan: Hapus subvolume rootfs jika ada
        if btrfs subvolume list /mnt/btrfs-top | grep -q "^.* path rootfs$"; then
            echo "🗑️  Menghapus subvolume rootfs dari $DEV"
            btrfs subvolume delete /mnt/btrfs-top/rootfs
        fi

        echo "📋 Subvolume SETELAH penghapusan:"
        btrfs subvolume list /mnt/btrfs-top
        umount /mnt/btrfs-top
        break
    fi
done
rmdir /mnt/btrfs-top

# Unmount rootfs
umount /mnt/rootfs
rm -rf /mnt/rootfs
sync

# Sukses dan prompt sebelum reboot
echo "✅ Proses perpindahan @home ke @ berhasil"
