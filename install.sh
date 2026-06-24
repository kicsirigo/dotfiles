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
print_step "4" "Rendszerszolgáltatások aktiválása"
sudo systemctl enable --now NetworkManager || print_warn "NetworkManager nem érhető el"
sudo systemctl enable --now bluetooth || print_warn "Bluetooth nem érhető el"
sudo systemctl enable --now systemd-resolved || print_warn "Systemd-resolved nem érhető el"
sudo systemctl enable --now fstrim.timer || print_warn "Fstrim.timer nem támogatott ezen a rendszeren"

# Disable SDDM, enable Ly as the default greeter
print_info "Greeter beállítása: ly aktiválása, sddm letiltása..."
sudo systemctl disable sddm || print_warn "SDDM nem volt engedélyezve"
sudo systemctl enable ly || print_warn "Ly nem érhető el"
sudo systemctl set-default graphical.target || print_warn "graphical.target nem állítható be"

print_success "Rendszerszolgáltatások sikeresen konfigurálva."

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
