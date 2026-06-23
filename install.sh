#!/bin/bash

# Hiba esetén álljon le a futás
set -e

echo "--- 1. Alapvető építőeszközök telepítése ---"
sudo pacman -S --needed --noconfirm base-devel git rsync

# 2. Yay telepítése (AUR támogatáshoz)
if ! command -v yay &> /dev/null; then
    echo "--- 2. Yay telepítése ---"
    # Átmeneti mappába dolgozunk
    git clone https://archlinux.org /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
else
    echo "--- 2. Yay már telepítve van ---"
fi

# 3. Csomagok telepítése a listából
if [ -f "all_package.txt" ]; then
    echo "--- 3. Csomagok telepítése a listából ---"
    # A --needed kihagyja, amit az archinstall már feltett
    yay -S --needed --noconfirm - < all_package.txt
else
    echo "HIBA: all_package.txt nem található! (Futtasd a generáló parancsot a régi gépen!)"
    exit 1
fi

# 4. Szolgáltatások bekapcsolása (Network, Bluetooth, stb.)
echo "--- 4. Szolgáltatások aktiválása ---"
sudo systemctl enable --now NetworkManager || echo "NetworkManager nem található"
sudo systemctl enable --now bluetooth || echo "Bluetooth nem található"
sudo systemctl enable --now systemd-resolved || echo "Systemd-resolved nem található"
sudo systemctl enable --now fstrim.timer || echo "Fstrim nem támogatott"

# 5. Fájlok másolása
echo "--- 5. Konfigurációk másolása ---"

# Másoljuk a .config mappát
if [ -d ".config" ]; then
    echo "Másolás: .config/* -> $HOME/.config/"
    mkdir -p "$HOME/.config"
    rsync -av --no-perms --no-owner --no-group .config/ "$HOME/.config/"
fi

# Másoljuk a .bashrc-t
if [ -f ".bashrc" ]; then
    echo "Másolás: .bashrc -> $HOME/.bashrc"
    cp .bashrc "$HOME/.bashrc"
fi

echo "----------------------------------------------------"
echo " KÉSZ! Minden csomag fent van, a configok másolva. "
echo " Javasolt egy újraindítás: 'reboot'               "
echo "----------------------------------------------------"
