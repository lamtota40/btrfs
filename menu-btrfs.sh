#!/bin/bash

pause() {
    echo
    read -p "Tekan [Enter] untuk kembali ke menu utama..."
}

while true; do
    clear
    echo "==============================="
    echo "          Menu BTRFS           "
    echo "==============================="
    echo -n "status : "
    findmnt -n -o FSTYPE /
    echo "1. Migrate"
    echo "2. SnapShoot"
    echo "3. Restore"
    echo "4. Move @Home to @"
    echo "0. Exit"
    echo "==============================="
    read -p "Silahkan input pilihan anda : " pilihan

    case "$pilihan" in
        1)
            echo "[+] Opsi 1: Migrate"
            # Tambahkan script migrate di sini
            pause
            ;;
        2)
            echo "[+] Opsi 2: SnapShoot"
            # Tambahkan script snapshot di sini
            pause
            ;;
        3)
            echo "[+] Opsi 3: Restore"
            # Tambahkan script restore di sini
            pause
            ;;
        4)
            echo "[+] Opsi 4: Move @Home to @"
            # Tambahkan script pemindahan @home di sini
            pause
            ;;
        0)
            echo "Keluar dari program. Sampai jumpa!"
            exit 0
            ;;
        *)
            echo "Pilihan tidak dikenal!"
            pause
            ;;
    esac
done

