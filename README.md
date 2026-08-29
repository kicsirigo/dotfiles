# Arch Linux Dotfiles

A lightweight, simple dotfiles configuration for an Arch Linux system powered by Hyprland.

## Configured Applications

This repository contains configurations for the following tools:

- **Window Manager / Desktop Environment**: [Hyprland](.config/hypr) (100% configured using native **Lua** for Hyprland v0.55+)
- **Status Bar**: [Waybar](.config/waybar) (with UWSM integration & customized battery alerts)
- **Terminal Emulator**: [Kitty](.config/kitty) (configured to launch Fish shell)
- **Application Launcher**: [Rofi](.config/rofi) (Catppuccin theme)
- **Text Editors**: [Micro](.config/micro) (with filemanager plugin) & [Neovim](.config/nvim) (Micro-like keybindings)
- **System Monitor**: [Btop](.config/btop) (v1.4.7+)
- **Clipboard Manager**: [Clipse](.config/clipse) & [Clipse-GUI](.config/clipse-gui)
- **Logout Menu**: [Wlogout](.config/wlogout)
- **Theme/Appearance Manager**: [nwg-look](.config/nwg-look), [nwg-displays](.config/nwg-displays) & [Theme Switcher](.config/themes/theme_switcher) (Catppuccin Macchiato default)
- **Audio Equalizer**: [EasyEffects](.config/easyeffects)
- **Shells**: [Fish](.config/fish) (interactive shell with custom prompt) & Bash ([.bashrc](.bashrc))
- **Utilities**: [MTP Automount](.local/bin/mtp-automount.py) (Android USB auto-mount script & systemd service)

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
4. Enables essential services (NetworkManager, Bluetooth, systemd-resolved, fstrim, udisks2, usbmuxd).
5. Configures Plymouth boot splash (detects GPU for Early KMS and sets the Catppuccin theme).
6. Installs the Catppuccin GRUB theme.
7. Disables conflicting display managers and enables Ly display manager on TTY1.
8. Copies configurations from `.config/` to `~/.config/` and `.local/` to `~/.local/`.
9. Sets Fish shell as the default shell (if installed).

## Hyprland Configuration (Lua)

Starting with Hyprland v0.55+, configurations are written in Lua. This setup uses a modular design loaded via `hyprland.lua`:

- **[hyprland.lua](.config/hypr/hyprland.lua)**: Main entry point configuration.
- **[binds.lua](.config/hypr/binds.lua)**: Keybindings, UWSM session exit, DPMS screen off (`Super+Shift+B`), and theme switcher (`Super+Shift+T`).
- **[lookandfeel.lua](.config/hypr/lookandfeel.lua)**: Theme styling, active Catppuccin Macchiato borders, window decorations, and animations.
- **[monitors.lua](.config/hypr/monitors.lua)**: Display output positioning and resolution scaling.
- **[autostart.lua](.config/hypr/autostart.lua)**: Startup processes (dbus activation, gnome-keyring, udiskie).
- **[hyprsunset.lua](.config/hypr/hyprsunset.lua)**: Blue light filter and color temperature adjustment.
- **[hyprlock.lua](.config/hypr/hyprlock.lua)**: Lockscreen configuration written in Lua.
- **[hypridle.lua](.config/hypr/hypridle.lua)**: Idle daemon configuration.
- **[screenoff.lua](.config/hypr/screenoff.lua)**: Power-saving display off logic.
- Other modular configurations include `aliases.lua`, `enviroment-variables.lua`, `permissions.lua`, `windows-and-workspaces.lua`, and `workspaces.lua`.

> [!NOTE]
> All legacy `.conf` configuration files across all Hyprland configurations (including lockscreen, idle, and sunset settings) have been completely removed in favor of native `.lua` configuration files.

## Neovim Configuration (Micro-like)

The Neovim configuration in [.config/nvim](.config/nvim) is preconfigured to mimic the intuitive keybindings and workflow of the Micro editor, while keeping all the power of Neovim under the hood.

- **Familiar Keybindings**: Standard shortcuts for save (`Ctrl+S`), quit (`Ctrl+Q`), open file (`Ctrl+O`), search (`Ctrl+F`), selection (`Shift+Arrows`, `Ctrl+A`), clipboard (`Ctrl+C`, `Ctrl+V`, `Ctrl+X`), tabs (`Ctrl+T` new buffer, `Ctrl+W` close buffer, `Alt+,`/`Alt+.` switch buffers), and terminal (`Ctrl+B`).
- **File Explorer Sidebar**: Press `Ctrl+H` to toggle the Neo-tree sidebar.
- **Fuzzy Finder**: Press `Ctrl+O` to search files in the workspace via Telescope.
- **Visuals**: Uses the Catppuccin Macchiato colorscheme by default to match the overall system style, paired with `lualine` for status bar info.




