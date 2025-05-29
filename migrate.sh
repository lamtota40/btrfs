#!/bin/bash
# Script migrasi partisi ext4 ke btrfs
# Pastikan dijalankan dari Live USB atau sistem lain (bukan dari partisi yang dimigrasi)

# === KONFIGURASI ===
OLD_PART="/dev/sda2"               # Partisi asal (ext4)
NEW_FS_TYPE="btrfs"
BACKUP_DIR="/mnt/backup"           # Lokasi sementara backup
MOUNT_POINT="/mnt/target"          # Tempat mount partisi btrfs

# === CEK HAK AKSES ROOT ===
if [[ $EUID -ne 0 ]]; then
  echo "Harus dijalankan sebagai root!"
  exit 1
fi

echo "[+] Mounting partisi lama..."
mkdir -p "$BACKUP_DIR"
mount "$OLD_PART" "$BACKUP_DIR" || {
  echo "Gagal mount $OLD_PART"
  exit 1
}

echo "[+] Backup data..."
mkdir -p "$MOUNT_POINT"
rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} "$BACKUP_DIR"/ "$BACKUP_DIR.bak"/ || {
  echo "Backup gagal!"
  exit 1
}
umount "$OLD_PART"

echo "[+] Format partisi ke btrfs..."
mkfs.btrfs -f "$OLD_PART" || {
  echo "Format btrfs gagal!"
  exit 1
}

echo "[+] Mount partisi btrfs..."
mount "$OLD_PART" "$MOUNT_POINT" || {
  echo "Gagal mount btrfs!"
  exit 1
}

echo "[+] Restore data ke btrfs..."
rsync -aAXv "$BACKUP_DIR.bak"/ "$MOUNT_POINT"/ || {
  echo "Restore gagal!"
  exit 1
}

echo "[+] Update fstab..."
UUID=$(blkid -s UUID -o value "$OLD_PART")
sed -i "s|^.* / .*|UUID=$UUID / $NEW_FS_TYPE defaults 0 1|" "$MOUNT_POINT/etc/fstab"

echo "[+] Reinstall GRUB (opsional)"
read -p "Ingin reinstall GRUB? (y/n): " ans
if [[ $ans == "y" || $ans == "Y" ]]; then
  mount --bind /dev "$MOUNT_POINT/dev"
  mount --bind /proc "$MOUNT_POINT/proc"
  mount --bind /sys "$MOUNT_POINT/sys"
  chroot "$MOUNT_POINT" /bin/bash -c "
    grub-install /dev/sda
    update-grub
  "
fi

echo "[✓] Migrasi selesai. Kamu bisa reboot sekarang."
