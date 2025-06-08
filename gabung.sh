#!/bin/bash

# Fungsi: get_subvolid <subvolume_name>
get_subvolid() {
    local NAME="$1"
    # Pastikan mountpoint ada
    local TOP_MP="/mnt/btrfs-top"
    sudo mkdir -p "$TOP_MP"

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        if sudo mount -o subvolid=5 "$DEV" "$TOP_MP" 2>/dev/null; then
            ID=$(sudo btrfs subvolume list "$TOP_MP" | awk -v name="$NAME" '$NF==name {print $2}')
            sudo umount "$TOP_MP"
            if [ -n "$ID" ]; then
                echo "$ID"
                sudo rmdir "$TOP_MP" 2>/dev/null || true
                return 0
            fi
        fi
    done
    sudo rmdir "$TOP_MP" 2>/dev/null || true
    return 1
}

# Fungsi: mount_subvol <mount_point> <subvolume_name>
mount_subvol() {
    local MOUNT_POINT="$1"
    local SUBVOL="$2"

    if [ -z "$MOUNT_POINT" ] || [ -z "$SUBVOL" ]; then
        echo "❌ mount_subvol membutuhkan 2 argumen: <mount_point> <subvolume>"
        return 1
    fi

    [ ! -d "$MOUNT_POINT" ] && sudo mkdir -p "$MOUNT_POINT"

    local ID=$(get_subvolid "$SUBVOL")
    if [ -z "$ID" ]; then
        echo "❌ Subvolume $SUBVOL tidak ditemukan!"
        return 1
    fi

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvolid=$ID ke $MOUNT_POINT"
        if sudo mount -o subvolid=$ID "$DEV" "$MOUNT_POINT" 2>/dev/null; then
            echo "✅ Berhasil mount $DEV ke $MOUNT_POINT dengan subvolid=$ID"
            return 0
        else
            echo "❌  Gagal mount $DEV"
        fi
    done

    echo "❌ Tidak ada partisi Btrfs yang berhasil di-mount dengan subvolid=$ID"
    return 1
}

# Cek apakah subvolume @home ada
echo "🔍 Mengecek keberadaan subvolume @home..."
if ! get_subvolid "@home" >/dev/null; then
    echo "❌ Subvolume @home tidak ditemukan, menghentikan proses."
    exit 1
fi

# Mount rootfs (@)
sudo mkdir -p /mnt/rootfs
mount_subvol /mnt/rootfs @

# Siapkan direktori home di rootfs
[ -d /mnt/rootfs/home ] && sudo rm -rf /mnt/rootfs/home
sudo mkdir -p /mnt/rootfs/home

# Mount home (@home)
sudo mkdir -p /mnt/homefs
mount_subvol /mnt/homefs @home

# Tampilkan list subvolume sebelum proses
echo "📋 Subvolume SEBELUM pemindahan:"
sudo mkdir -p /mnt/btrfs-top
for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
    if sudo mount -o subvolid=5 "$DEV" /mnt/btrfs-top 2>/dev/null; then
        sudo btrfs subvolume list /mnt/btrfs-top
        sudo umount /mnt/btrfs-top
        break
    fi

done

# Pindahkan isi @home ke /home dalam @
sudo rsync -a /mnt/homefs/ /mnt/rootfs/home/

# Bersihkan homefs
sudo umount /mnt/homefs
sudo rm -rf /mnt/homefs

# Backup dan edit fstab
sudo cp /mnt/rootfs/etc/fstab /mnt/rootfs/etc/fstab.bak
sudo sed -i '/^[^#]*[[:space:]]\/home[[:space:]]\+btrfs.*subvol=@home/d' /mnt/rootfs/etc/fstab

# Persiapan chroot
sudo mount --bind /dev /mnt/rootfs/dev
sudo mount --bind /proc /mnt/rootfs/proc
sudo mount --bind /sys /mnt/rootfs/sys

# Jalankan grub di chroot
sudo chroot /mnt/rootfs /bin/bash -c "
grub-reboot 0
grub-set-default 'Ubuntu'
update-grub
"

# Cleanup mount
sudo umount /mnt/rootfs/dev
sudo umount /mnt/rootfs/proc
sudo umount /mnt/rootfs/sys

# Hapus subvolume @home dari top-level
sudo mkdir -p /mnt/btrfs-top
for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
    if sudo mount -o subvolid=5 "$DEV" /mnt/btrfs-top 2>/dev/null; then
        if sudo btrfs subvolume list /mnt/btrfs-top | grep -q "@home"; then
            echo "🗑️  Menghapus subvolume @home dari $DEV"
            sudo btrfs subvolume delete /mnt/btrfs-top/@home
        fi
        echo "📋 Subvolume SETELAH penghapusan:"
        sudo btrfs subvolume list /mnt/btrfs-top
        sudo umount /mnt/btrfs-top
        break
    fi
done
sudo rmdir /mnt/btrfs-top

# Unmount rootfs
sudo umount /mnt/rootfs
sync

# Sukses dan prompt sebelum reboot
echo
echo "✅ Proses perpindahan @home ke @ berhasil"

read -p "Silakan tekan [ENTER] untuk melanjutkan reboot atau CTRL+C untuk membatalkan..."
sudo reboot
