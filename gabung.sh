#!/bin/bash

# Fungsi: mount_subvol <mount_point> <subvolume_name>
mount_subvol() {
    local MOUNT_POINT="$1"
    local SUBVOL="$2"

    if [ -z "$MOUNT_POINT" ] || [ -z "$SUBVOL" ]; then
        echo "❌ mount_subvol membutuhkan 2 argumen: <mount_point> <subvolume>"
        return 1
    fi

    [ ! -d "$MOUNT_POINT" ] && sudo mkdir -p "$MOUNT_POINT"

    for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
        echo "🔍 Mencoba mount $DEV -o subvol=$SUBVOL ke $MOUNT_POINT"
        if sudo mount -o subvol=$SUBVOL "$DEV" "$MOUNT_POINT" 2>/dev/null; then
            echo "✅ Berhasil mount $DEV ke $MOUNT_POINT dengan subvol=$SUBVOL"
            return 0
        else
            echo "❌ Gagal mount $DEV"
        fi
    done

    echo "❌ Tidak ada partisi Btrfs yang berhasil di-mount dengan subvol=$SUBVOL"
    return 1
}

# Mount rootfs (@)
sudo mkdir -p /mnt/rootfs
mount_subvol /mnt/rootfs @

# Siapkan direktori home di rootfs
[ -d /mnt/rootfs/home ] && sudo rm -rf /mnt/rootfs/home
sudo mkdir -p /mnt/rootfs/home

# Mount home (@home)
sudo mkdir -p /mnt/homefs
mount_subvol /mnt/homefs @home

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

# Tambahan: hapus subvolume @home dari top-level
sudo mkdir -p /mnt/btrfs-top
for DEV in $(lsblk -pnlo NAME,FSTYPE | awk '$2=="btrfs"{print $1}'); do
    if sudo mount -o subvolid=5 "$DEV" /mnt/btrfs-top 2>/dev/null; then
        if sudo btrfs subvolume list /mnt/btrfs-top | grep -q "@home"; then
            echo "🗑️  Menghapus subvolume @home dari $DEV"
            sudo btrfs subvolume delete /mnt/btrfs-top/@home
        fi
        sudo umount /mnt/btrfs-top
        break
    fi
done
sudo rmdir /mnt/btrfs-top

# Unmount rootfs
sudo umount /mnt/rootfs

# Sukses dan prompt sebelum reboot
echo "✅ Proses perpindahan @home ke @ berhasil"
echo "Silakan tekan [ENTER] untuk melanjutkan reboot atau CTRL+C untuk membatalkan..."
read

sync
sudo reboot
