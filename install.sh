#!/bin/bash

# Hiba esetén álljon le a futás
set -e

# Színek definíciója (Catppuccin ihlette stílus)
CORAL='\033[38;2;244;219;214m'
MAUVE='\033[38;2;198;160;246m'
BLUE='\033[38;2;138;173;244m'
GREEN='\033[38;2;166;218;149m'
YELLOW='\033[38;2;238;212;159m'
RED='\033[38;2;237;135;150m'
CYAN='\033[38;2;139;213;202m'
BOLD='\033[1m'
NC='\033[0m' # Nincs szín

# Ikonok (Nerd Fonts támogatással)
ICON_GEAR=""
ICON_CHECK=""
ICON_ARROW="➜"
ICON_INFO=""
ICON_WARN=""

# Segédfüggvények a szép kiíráshoz
print_header() {
    clear 2>/dev/null || true
    echo -e "${MAUVE}${BOLD}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${MAUVE}${BOLD}│            Arch Linux Dotfiles Telepítő          │${NC}"
    echo -e "${MAUVE}${BOLD}╰──────────────────────────────────────────────────╯${NC}"
    echo ""
}

print_step() {
    local step_num=$1
    local step_desc=$2
    echo -e "\n${BLUE}${BOLD}[$step_num/6] ${ICON_GEAR} $step_desc${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────${NC}"
}

print_success() {
    echo -e "${GREEN}${ICON_CHECK} $1${NC}"
}

print_info() {
    echo -e "${CYAN}${ICON_INFO} $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}${ICON_WARN} $1${NC}"
}

# --- Kezdőképernyő ---
print_header
print_info "A telepítési folyamat elindul..."

# --- 1. LÉPÉS ---
print_step "1" "Alapvető építőeszközök telepítése"
sudo pacman -S --needed --noconfirm base-devel git rsync
print_success "Alapeszközök sikeresen telepítve."

# --- 2. LÉPÉS ---
print_step "2" "Yay (AUR segéd) telepítése"
if ! command -v yay &> /dev/null; then
    print_info "Yay nem található, telepítés elindítása az AUR-ból..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd - > /dev/null
    rm -rf /tmp/yay
    print_success "Yay sikeresen telepítve."
else
    print_success "Yay már telepítve van, lépés kihagyása."
fi

# --- 3. LÉPÉS ---
print_step "3" "Csomagok telepítése a listából"
if [ -f "all_package.txt" ]; then
    print_info "Rendszer csomagok szinkronizálása az all_package.txt alapján..."
    yay -S --needed --noconfirm $(cat all_package.txt)
    print_success "Minden csomag sikeresen szinkronizálva."
else
    echo -e "${RED}${BOLD}HIBA: all_package.txt nem található!${NC}"
    exit 1
fi

# --- 4. LÉPÉS ---
print_step "4" "Rendszerszolgáltatások és Plymouth beállítása"
sudo systemctl enable --now NetworkManager || print_warn "NetworkManager nem érhető el"
sudo systemctl enable --now bluetooth || print_warn "Bluetooth nem érhető el"
sudo systemctl enable --now systemd-resolved || print_warn "Systemd-resolved nem érhető el"
sudo systemctl enable --now fstrim.timer || print_warn "Fstrim.timer nem támogatott ezen a rendszeren"

# Plymouth konfigurálása
print_info "Plymouth beállítása..."
if [ -f "/etc/mkinitcpio.conf" ]; then
    # Plymouth hook hozzáadása
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        print_info "Plymouth hook hozzáadása a /etc/mkinitcpio.conf-hoz..."
        sudo sed -i 's/\(HOOKS=(.*udev\)/\1 plymouth/' /etc/mkinitcpio.conf
    fi
    # Korai KMS (GPU modulok hozzáadása a MODULES tömbhöz)
    gpu_module=""
    if lspci | grep -qi "intel"; then
        gpu_module="i915"
    elif lspci | grep -qi "amd"; then
        gpu_module="amdgpu"
    elif lspci | grep -qi "nvidia"; then
        gpu_module="nouveau"
    fi
    if [ -n "$gpu_module" ]; then
        if ! grep -q "MODULES=(\([^)]* \)*$gpu_module\([ )]\|$\)" /etc/mkinitcpio.conf; then
            print_info "Korai KMS beállítása: $gpu_module modul hozzáadása a mkinitcpio-hoz..."
            sudo sed -i "s/MODULES=(\([^)]*\))/MODULES=(\1 $gpu_module)/" /etc/mkinitcpio.conf
            sudo sed -i "s/MODULES=(\s*/MODULES=(/" /etc/mkinitcpio.conf
        fi
    fi
fi

# Kernel paraméterek beállítása (GRUB és UKI /etc/kernel/cmdline esetén is)
if [ -f "/etc/default/grub" ]; then
    if ! grep -q "splash" /etc/default/grub; then
        print_info "Splash kernel paraméter hozzáadása a /etc/default/grub-hoz..."
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
    fi
fi
if [ -f "/etc/kernel/cmdline" ]; then
    if ! grep -q "splash" /etc/kernel/cmdline; then
        print_info "Splash és quiet kernel paraméter hozzáadása a /etc/kernel/cmdline-hoz..."
        sudo sed -i 's/$/ quiet splash/' /etc/kernel/cmdline
    fi
fi

# Plymouth téma beállítása
if command -v plymouth-set-default-theme &>/dev/null; then
    print_info "Catppuccin Plymouth téma beállítása..."
    sudo plymouth-set-default-theme -R catppuccin-macchiato || print_warn "Plymouth téma beállítása sikertelen"
fi

# GRUB téma beállítása és konfiguráció újragenerálása
if command -v grub-mkconfig &>/dev/null; then
    if [ ! -d "/usr/share/grub/themes/catppuccin-macchiato" ]; then
        print_info "Catppuccin GRUB téma letöltése és beállítása..."
        git clone https://github.com/catppuccin/grub.git /tmp/grub_theme_repo || print_warn "GRUB téma letöltése sikertelen"
        if [ -d "/tmp/grub_theme_repo" ]; then
            sudo mkdir -p /usr/share/grub/themes
            sudo cp -r /tmp/grub_theme_repo/src/catppuccin-macchiato-grub-theme /usr/share/grub/themes/catppuccin-macchiato
            rm -rf /tmp/grub_theme_repo
        fi
    fi
    if [ -d "/usr/share/grub/themes/catppuccin-macchiato" ]; then
        if grep -q "GRUB_THEME=" /etc/default/grub; then
            sudo sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/usr/share/grub/themes/catppuccin-macchiato/theme.txt"|' /etc/default/grub
        else
            echo 'GRUB_THEME="/usr/share/grub/themes/catppuccin-macchiato/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
        fi
    fi
    print_info "GRUB konfiguráció újragenerálása..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg || print_warn "GRUB konfiguráció újragenerálása sikertelen"
fi
if [ -f "/etc/kernel/cmdline" ] || [ -d "/boot/EFI/Linux" ]; then
    print_info "UKI / initramfs újragenerálása (mkinitcpio -P)..."
    sudo mkinitcpio -P || print_warn "mkinitcpio futtatása sikertelen"
fi

# Disable SDDM, enable Ly as the default greeter
print_info "Greeter beállítása: ly@tty1 aktiválása, sddm letiltása..."
sudo systemctl disable sddm || print_warn "SDDM nem volt engedélyezve"
sudo systemctl disable getty@tty1.service || print_warn "getty@tty1 nem letiltható"
sudo systemctl enable ly@tty1.service || print_warn "Ly nem érhető el"
sudo systemctl set-default graphical.target || print_warn "graphical.target nem állítható be"

print_success "Rendszerszolgáltatások és Plymouth sikeresen konfigurálva."

# --- 5. LÉPÉS ---
print_step "5" "Konfigurációs fájlok másolása"
# Másoljuk a .config mappát
if [ -d ".config" ]; then
    print_info "Konfigurációk másolása: .config/* -> $HOME/.config/"
    mkdir -p "$HOME/.config"
    rsync -av --no-perms --no-owner --no-group .config/ "$HOME/.config/"
    print_success ".config fájlok átmásolva."
fi

# Másoljuk a .bashrc-t
if [ -f ".bashrc" ]; then
    print_info "Konfigurációk másolása: .bashrc -> $HOME/.bashrc"
    cp .bashrc "$HOME/.bashrc"
    print_success ".bashrc fájl átmásolva."
fi

# --- 6. LÉPÉS ---
print_step "6" "Fish shell beállítása alapértelmezettként"
if command -v fish &>/dev/null; then
    FISH_PATH="$(command -v fish)"
    if ! grep -q "${FISH_PATH}" /etc/shells; then
        echo "${FISH_PATH}" | sudo tee -a /etc/shells
    fi
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "${FISH_PATH}" ]; then
        chsh -s "${FISH_PATH}"
        print_success "Fish shell beállítva alapértelmezettként: ${FISH_PATH}"
    else
        print_success "Fish shell már alapértelmezett."
    fi
else
    print_warn "Fish shell nem található, csomag telepítés ellenőrzendő."
fi

# --- Befejezés ---
echo -e "\n${GREEN}${BOLD}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}${BOLD}│      KÉSZ! Minden csomag és config a helyén.     │${NC}"
    echo -e "${GREEN}${BOLD}│      Javasolt egy újraindítás: 'reboot'          │${NC}"
    echo -e "${GREEN}${BOLD}╰──────────────────────────────────────────────────╯${NC}\n"
