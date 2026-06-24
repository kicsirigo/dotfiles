#!/bin/bash

# Exit on error
set -e

# Color definitions (Catppuccin inspired style)
CORAL='\033[38;2;244;219;214m'
MAUVE='\033[38;2;198;160;246m'
BLUE='\033[38;2;138;173;244m'
GREEN='\033[38;2;166;218;149m'
YELLOW='\033[38;2;238;212;159m'
RED='\033[38;2;237;135;150m'
CYAN='\033[38;2;139;213;202m'
BOLD='\033[1m'
NC='\033[0m' # No color

# Icons (with Nerd Fonts support)
ICON_GEAR=""
ICON_CHECK=""
ICON_ARROW="➜"
ICON_INFO=""
ICON_WARN=""

# Helper functions for pretty output
print_header() {
    clear 2>/dev/null || true
    echo -e "${MAUVE}${BOLD}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${MAUVE}${BOLD}│            Arch Linux Dotfiles Installer         │${NC}"
    echo -e "${MAUVE}${BOLD}╰──────────────────────────────────────────────────╯${NC}"
    echo ""
}

print_step() {
    local step_num=$1
    local step_desc=$2
    echo -e "\n${BLUE}${BOLD}[$step_num/7] ${ICON_GEAR} $step_desc${NC}"
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

# --- Welcome Screen ---
print_header
print_info "Starting the installation process..."

# --- STEP 1 ---
print_step "1" "Installing basic build tools"
sudo pacman -S --needed --noconfirm base-devel git rsync
print_success "Basic tools installed successfully."

# --- STEP 2 ---
print_step "2" "Installing Yay (AUR helper)"
if ! command -v yay &> /dev/null; then
    print_info "Yay not found, starting installation from AUR..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd - > /dev/null
    rm -rf /tmp/yay
    print_success "Yay installed successfully."
else
    print_success "Yay is already installed, skipping step."
fi

# --- STEP 3 ---
print_step "3" "Installing packages from list"
if [ -f "all_package.txt" ]; then
    print_info "Syncing system packages based on all_package.txt..."
    yay -S --needed --noconfirm $(cat all_package.txt)
    print_success "All packages synced successfully."
else
    echo -e "${RED}${BOLD}ERROR: all_package.txt not found!${NC}"
    exit 1
fi

# --- STEP 4 ---
print_step "4" "Configuring system services and Plymouth"
sudo systemctl enable --now NetworkManager || print_warn "NetworkManager is not available"
sudo systemctl enable --now bluetooth || print_warn "Bluetooth is not available"
# Clear stale Bluetooth device cache to prevent blueman from hanging on scan
print_info "Clearing Bluetooth device cache (blueman fix)..."
sudo rm -rf /var/lib/bluetooth/*
sudo systemctl restart bluetooth || print_warn "Failed to restart Bluetooth"
print_success "Bluetooth cache cleared and service restarted."
sudo systemctl enable --now systemd-resolved || print_warn "Systemd-resolved is not available"
sudo systemctl enable --now fstrim.timer || print_warn "Fstrim.timer is not supported on this system"

# Plymouth configuration
print_info "Configuring Plymouth..."
if [ -f "/etc/mkinitcpio.conf" ]; then
    # Add Plymouth hook
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        print_info "Adding Plymouth hook to /etc/mkinitcpio.conf..."
        sudo sed -i 's/\(HOOKS=(.*udev\)/\1 plymouth/' /etc/mkinitcpio.conf
    fi
    # Early KMS (Adding GPU modules to MODULES array)
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
            print_info "Setting up early KMS: adding $gpu_module module to mkinitcpio..."
            sudo sed -i "s/MODULES=(\([^)]*\))/MODULES=(\1 $gpu_module)/" /etc/mkinitcpio.conf
            sudo sed -i "s/MODULES=(\s*/MODULES=(/" /etc/mkinitcpio.conf
        fi
    fi
fi

# Set kernel parameters (GRUB and UKI /etc/kernel/cmdline as well)
if [ -f "/etc/default/grub" ]; then
    if ! grep -q "splash" /etc/default/grub; then
        print_info "Adding splash kernel parameter to /etc/default/grub..."
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 splash"/' /etc/default/grub
    fi
fi
if [ -f "/etc/kernel/cmdline" ]; then
    if ! grep -q "splash" /etc/kernel/cmdline; then
        print_info "Adding splash and quiet kernel parameters to /etc/kernel/cmdline..."
        sudo sed -i 's/$/ quiet splash/' /etc/kernel/cmdline
    fi
fi

# Set Plymouth theme
if command -v plymouth-set-default-theme &>/dev/null; then
    print_info "Setting Catppuccin Plymouth theme..."
    sudo plymouth-set-default-theme -R catppuccin-macchiato || print_warn "Failed to set Plymouth theme"
fi

# Set GRUB theme and regenerate config
if command -v grub-mkconfig &>/dev/null; then
    if [ ! -d "/usr/share/grub/themes/catppuccin-macchiato" ]; then
        print_info "Downloading and setting Catppuccin GRUB theme..."
        git clone https://github.com/catppuccin/grub.git /tmp/grub_theme_repo || print_warn "Failed to download GRUB theme"
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
    print_info "Regenerating GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg || print_warn "Failed to regenerate GRUB configuration"
fi
if [ -f "/etc/kernel/cmdline" ] || [ -d "/boot/EFI/Linux" ]; then
    print_info "Regenerating UKI / initramfs (mkinitcpio -P)..."
    sudo mkinitcpio -P || print_warn "Failed to run mkinitcpio"
fi

# Disable SDDM, enable Ly as the default greeter
print_info "Configuring greeter: enabling ly@tty1, disabling sddm..."
sudo systemctl disable sddm || print_warn "SDDM was not enabled"
sudo systemctl disable getty@tty1.service || print_warn "getty@tty1 could not be disabled"
sudo systemctl enable ly@tty1.service || print_warn "Ly is not available"
sudo systemctl set-default graphical.target || print_warn "graphical.target could not be set"

print_success "System services and Plymouth configured successfully."

# --- STEP 5 ---
print_step "5" "Copying configuration files"
# Copy .config directory
if [ -d ".config" ]; then
    print_info "Copying configs: .config/* -> $HOME/.config/"
    mkdir -p "$HOME/.config"
    rsync -av --no-perms --no-owner --no-group .config/ "$HOME/.config/"
    print_success ".config files copied."
fi

# Copy .bashrc
if [ -f ".bashrc" ]; then
    print_info "Copying config: .bashrc -> $HOME/.bashrc"
    cp .bashrc "$HOME/.bashrc"
    print_success ".bashrc file copied."
fi

# --- STEP 6 ---
print_step "6" "Setting Fish shell as default"
if command -v fish &>/dev/null; then
    FISH_PATH="$(command -v fish)"
    if ! grep -q "${FISH_PATH}" /etc/shells; then
        echo "${FISH_PATH}" | sudo tee -a /etc/shells
    fi
    if [ "$(getent passwd "$USER" | cut -d: -f7)" != "${FISH_PATH}" ]; then
        chsh -s "${FISH_PATH}"
        print_success "Fish shell set as default: ${FISH_PATH}"
    else
        print_success "Fish shell is already default."
    fi
else
    print_warn "Fish shell not found, please check package installation."
fi

# --- STEP 7 ---
print_step "7" "Cleaning up unused GTK theme variants"
# Clean up unused Catppuccin Macchiato themes under /usr/share/themes
print_info "Cleaning up unused Catppuccin Macchiato variants from /usr/share/themes/..."
for dir in /usr/share/themes/catppuccin-macchiato-*; do
    if [ -d "${dir}" ] && [[ "${dir}" != *"-lavender-"* ]]; then
        sudo rm -rf "${dir}"
    fi
done

# Clean up unused Nordic themes under ~/.local/share/themes
if [ -d "$HOME/.local/share/themes" ]; then
    print_info "Cleaning up unused Nordic variants from $HOME/.local/share/themes/..."
    for dir in "$HOME/.local/share/themes"/Nordic-*; do
        if [ -d "${dir}" ]; then
            rm -rf "${dir}"
        fi
    done
fi
print_success "Unused GTK theme variants cleaned up."

# --- Finish ---
echo -e "\n${GREEN}${BOLD}╭──────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}${BOLD}│      DONE! All packages and configs in place.   │${NC}"
    echo -e "${GREEN}${BOLD}│      A system reboot is recommended: 'reboot'    │${NC}"
    echo -e "${GREEN}${BOLD}╰──────────────────────────────────────────────────╯${NC}\n"
