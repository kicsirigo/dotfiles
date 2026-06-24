#!/bin/bash

# Exit on error
set -e

# Color definitions (High-intensity 16-color ANSI escape sequences for minimal CLI/TTY support)
CORAL='\033[91m'   # Light Red
MAUVE='\033[95m'   # Light Magenta
BLUE='\033[94m'    # Light Blue
GREEN='\033[92m'   # Light Green
YELLOW='\033[93m'  # Light Yellow
RED='\033[31m'     # Standard Red
CYAN='\033[96m'    # Light Cyan
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

# --- Pretty Execution Helper with Verbose Toggle ---
VERBOSE=false

run_pretty() {
    local step_desc="$1"
    shift
    local cmd="$*"
    
    local log_file=$(mktemp)
    
    # Run the command in the background, redirecting output
    eval "$cmd" > "$log_file" 2>&1 &
    local pid=$!
    
    local spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spinner_colors=("$MAUVE" "$BLUE" "$CYAN" "$GREEN" "$YELLOW" "$CORAL")
    local frame_idx=0
    local color_idx=0
    local last_line_count=0
    local verbose_lines_printed=0
    
    while kill -0 "$pid" 2>/dev/null; do
        local key=""
        # Non-blocking silent read from terminal tty
        if read -s -t 0.08 -n 1 key < /dev/tty 2>/dev/null; then
            if [ "$key" = "." ]; then
                if [ "$VERBOSE" = true ]; then
                    VERBOSE=false
                    # Erase all verbose lines printed in the current step session
                    while [ "$verbose_lines_printed" -gt 0 ]; do
                        printf "\033[1A\033[2K"
                        verbose_lines_printed=$((verbose_lines_printed - 1))
                    done
                    printf "\r\033[K" # Clear current line
                    echo -e "${YELLOW}➜ Toggled verbose mode OFF. Returning to loading animation...${NC}"
                else
                    VERBOSE=true
                    printf "\r\033[K"
                    echo -e "${CYAN}➜ Toggled verbose mode ON. Showing output details...${NC}"
                    last_line_count=0
                    verbose_lines_printed=0
                fi
            fi
        fi
        
        if [ "$VERBOSE" = true ]; then
            local current_line_count=$(wc -l < "$log_file")
            if [ "$current_line_count" -gt "$last_line_count" ]; then
                local lines_to_print=$(tail -n +"$((last_line_count + 1))" "$log_file")
                if [ -n "$lines_to_print" ]; then
                    echo "$lines_to_print"
                    local new_lines=$(echo "$lines_to_print" | wc -l)
                    verbose_lines_printed=$((verbose_lines_printed + new_lines))
                fi
                last_line_count=$current_line_count
            fi
        else
            local frame="${spinner_frames[frame_idx]}"
            local color="${spinner_colors[color_idx]}"
            printf "\r${color}%s${NC} %s... [Press '.' to show details]" "$frame" "$step_desc"
            
            frame_idx=$(( (frame_idx + 1) % ${#spinner_frames[@]} ))
            color_idx=$(( (color_idx + 1) % ${#spinner_colors[@]} ))
        fi
    done
    
    # Wait for the background process to finish and get exit code
    wait "$pid"
    local exit_status=$?
    
    # Clear the spinner line
    printf "\r\033[K"
    
    if [ "$exit_status" -eq 0 ]; then
        print_success "$step_desc completed successfully."
    else
        echo -e "${RED}${BOLD}ERROR: $step_desc failed (Exit code: $exit_status).${NC}"
        echo -e "${RED}Last 15 lines of output:${NC}"
        tail -n 15 "$log_file"
        rm -f "$log_file"
        exit 1
    fi
    
    rm -f "$log_file"
}

# --- Welcome Screen ---
print_header

# Request sudo credentials upfront and keep them refreshed in the background
print_info "This script requires administrative privileges for system-wide configuration."
print_info "Prompting for sudo password upfront..."
sudo -v

# Background loop to keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

print_info "Starting the installation process..."

# --- STEP 1 ---
print_step "1" "Installing basic build tools"
run_pretty "Installing base-devel, git, and rsync" sudo pacman -S --needed --noconfirm base-devel git rsync

# --- STEP 2 ---
print_step "2" "Installing Yay (AUR helper)"
if ! command -v yay &> /dev/null; then
    run_pretty "Building and installing Yay from AUR" "git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm && rm -rf /tmp/yay"
else
    print_success "Yay is already installed, skipping build."
fi

# --- STEP 3 ---
print_step "3" "Installing packages from list"
if [ -f "all_package.txt" ]; then
    run_pretty "Installing system packages via Yay" yay -S --needed --noconfirm $(cat all_package.txt)
else
    echo -e "${RED}${BOLD}ERROR: all_package.txt not found!${NC}"
    exit 1
fi

# --- STEP 4 ---
print_step "4" "Configuring system services and Plymouth"
run_pretty "Enabling NetworkManager and Bluetooth" "sudo systemctl enable --now NetworkManager && sudo systemctl enable --now bluetooth"

print_info "Clearing Bluetooth device cache (blueman fix)..."
run_pretty "Clearing Bluetooth cache" "sudo rm -rf /var/lib/bluetooth/* && sudo systemctl restart bluetooth"

run_pretty "Enabling systemd-resolved and fstrim" "sudo systemctl enable --now systemd-resolved && sudo systemctl enable --now fstrim.timer"

run_pretty "Configuring Plymouth hooks and Early KMS" "bash -c '
if [ -f \"/etc/mkinitcpio.conf\" ]; then
    if ! grep -q \"plymouth\" /etc/mkinitcpio.conf; then
        sudo sed -i \"s/\\(HOOKS=(.*udev\\)/\\1 plymouth/\" /etc/mkinitcpio.conf
    fi
    gpu_module=\"\"
    if lspci | grep -qi \"intel\"; then
        gpu_module=\"i915\"
    elif lspci | grep -qi \"amd\"; then
        gpu_module=\"amdgpu\"
    elif lspci | grep -qi \"nvidia\"; then
        gpu_module=\"nouveau\"
    fi
    if [ -n \"\$gpu_module\" ]; then
        if ! grep -q \"MODULES=(\\([^)]* \\)*\$gpu_module\\([ )]\\|\$\\)\" /etc/mkinitcpio.conf; then
            sudo sed -i \"s/MODULES=(\\([^)]*\\))/MODULES=(\\1 \$gpu_module)/\" /etc/mkinitcpio.conf
            sudo sed -i \"s/MODULES=(\\s*/MODULES=(/\" /etc/mkinitcpio.conf
        fi
    fi
fi
'"

run_pretty "Adding kernel parameters (splash/quiet)" "bash -c '
if [ -f \"/etc/default/grub\" ]; then
    if ! grep -q \"splash\" /etc/default/grub; then
        sudo sed -i \"s/GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 splash\"/\" /etc/default/grub
    fi
fi
if [ -f \"/etc/kernel/cmdline\" ]; then
    if ! grep -q \"splash\" /etc/kernel/cmdline; then
        sudo sed -i \"s/\$/ quiet splash/\" /etc/kernel/cmdline
    fi
fi
'"

run_pretty "Setting Plymouth Catppuccin theme" "bash -c '
if command -v plymouth-set-default-theme &>/dev/null; then
    sudo plymouth-set-default-theme -R catppuccin-macchiato
fi
'"

run_pretty "Installing Catppuccin GRUB theme" "bash -c '
if command -v grub-mkconfig &>/dev/null; then
    if [ ! -d \"/usr/share/grub/themes/catppuccin-macchiato\" ]; then
        git clone https://github.com/catppuccin/grub.git /tmp/grub_theme_repo
        if [ -d \"/tmp/grub_theme_repo\" ]; then
            sudo mkdir -p /usr/share/grub/themes
            sudo cp -r /tmp/grub_theme_repo/src/catppuccin-macchiato-grub-theme /usr/share/grub/themes/catppuccin-macchiato
            rm -rf /tmp/grub_theme_repo
        fi
    fi
    if [ -d \"/usr/share/grub/themes/catppuccin-macchiato\" ]; then
        if grep -q \"GRUB_THEME=\" /etc/default/grub; then
            sudo sed -i \"s|^#\\?GRUB_THEME=.*|GRUB_THEME=\\\"/usr/share/grub/themes/catppuccin-macchiato/theme.txt\\\"|\" /etc/default/grub
        else
            echo \"GRUB_THEME=\\\"/usr/share/grub/themes/catppuccin-macchiato/theme.txt\\\"\" | sudo tee -a /etc/default/grub >/dev/null
        fi
    fi
fi
'"

run_pretty "Regenerating boot configs and initramfs" "bash -c '
if command -v grub-mkconfig &>/dev/null; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi
if [ -f \"/etc/kernel/cmdline\" ] || [ -d \"/boot/EFI/Linux\" ]; then
    sudo mkinitcpio -P
fi
'"

run_pretty "Enabling Ly greeter" "bash -c '
sudo systemctl disable sddm || true
sudo systemctl disable getty@tty1.service || true
sudo systemctl enable ly@tty1.service || true
sudo systemctl set-default graphical.target || true
'"

# --- STEP 5 ---
print_step "5" "Copying configuration files"
run_pretty "Copying user .config directory" "bash -c '
if [ -d \".config\" ]; then
    mkdir -p \"\$HOME/.config\"
    rsync -av --no-perms --no-owner --no-group .config/ \"\$HOME/.config/\"
fi
'"

run_pretty "Copying .bashrc file" "bash -c '
if [ -f \".bashrc\" ]; then
    cp .bashrc \"\$HOME/.bashrc\"
fi
'"

# --- STEP 6 ---
print_step "6" "Setting Fish shell as default"
run_pretty "Configuring Fish as default login shell" "bash -c '
if command -v fish &>/dev/null; then
    FISH_PATH=\"\$(command -v fish)\"
    if ! grep -q \"\${FISH_PATH}\" /etc/shells; then
        echo \"\${FISH_PATH}\" | sudo tee -a /etc/shells >/dev/null
    fi
    if [ \"\$(getent passwd \"\$USER\" | cut -d: -f7)\" != \"\${FISH_PATH}\" ]; then
        chsh -s \"\${FISH_PATH}\"
    fi
fi
'"

# --- STEP 7 ---
print_step "7" "Cleaning up unused GTK theme variants"
run_pretty "Cleaning system and local theme variants" "bash -c '
for dir in /usr/share/themes/catppuccin-macchiato-*; do
    if [ -d \"\${dir}\" ] && [[ \"\${dir}\" != *\"-lavender-\"* ]]; then
        sudo rm -rf \"\${dir}\"
    fi
done

if [ -d \"\$HOME/.local/share/themes\" ]; then
    for dir in \"\$HOME/.local/share/themes\"/Nordic-*; do
        if [ -d \"\${dir}\" ]; then
            rm -rf \"\${dir}\"
        fi
    done
fi
'"

# --- Finish ---
echo -e "\n${GREEN}${BOLD}╭──────────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}${BOLD}│      DONE! All packages and configs in place.   │${NC}"
echo -e "${GREEN}${BOLD}│      A system reboot is recommended: 'reboot'    │${NC}"
echo -e "${GREEN}${BOLD}╰──────────────────────────────────────────────────╯${NC}\n"
