# Arch Linux Dotfiles

A lightweight, simple dotfiles configuration for an Arch Linux system powered by Hyprland.

## Configured Applications

This repository contains configurations for the following tools:

- **Window Manager / Desktop Environment**: [Hyprland](.config/hypr)
- **Status Bar**: [Waybar](.config/waybar)
- **Terminal Emulator**: [Kitty](.config/kitty)
- **Application Launcher**: [Rofi](.config/rofi)
- **Text Editor**: [Micro](.config/micro)
- **System Monitor**: [Btop](.config/btop)
- **Clipboard Manager**: [Clipse](.config/clipse)
- **Logout Menu**: [Wlogout](.config/wlogout)
- **Theme/Appearance Manager**: [nwg-look](.config/nwg-look) & [nwg-displays](.config/nwg-displays)
- **Shell**: Bash (via [.bashrc](.bashrc))

## Package List

The packages required for this setup are listed in `all_package.txt`.

## Installation

The installation is managed by a simple, direct-copy script (`install.sh`). 

### Running the installation

To install dependencies and copy the configuration files to your home directory, run:

```bash
chmod +x install.sh
./install.sh
```

### What the installer does:
1. Installs base development tools, git, and rsync.
2. Installs `yay` (if not already installed).
3. Installs all packages listed in `all_package.txt`.
4. Enables essential services (NetworkManager, Bluetooth, systemd-resolved, fstrim).
5. Configures Plymouth boot splash (detects GPU for Early KMS and sets the Catppuccin theme).
6. Installs the Catppuccin GRUB theme.
7. Disables conflicting display managers and enables Ly display manager on TTY1.
8. Copies configurations from `.config/` to `~/.config/` and `.bashrc` to `~/.bashrc`.
9. Sets Fish shell as the default shell (if installed).
