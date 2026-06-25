# Arch Linux Dotfiles

A lightweight, simple dotfiles configuration for an Arch Linux system powered by Hyprland.

## Configured Applications

This repository contains configurations for the following tools:

- **Window Manager / Desktop Environment**: [Hyprland](.config/hypr) (configured using **Lua** for Hyprland v0.55+)
- **Status Bar**: [Waybar](.config/waybar)
- **Terminal Emulator**: [Kitty](.config/kitty)
- **Application Launcher**: [Rofi](.config/rofi)
- **Text Editors**: [Micro](.config/micro) & [Neovim](.config/nvim) (Neovim behaves like Micro with familiar keybindings, file tree, and fuzzy finding)
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

## Hyprland Configuration (Lua)

Starting with Hyprland v0.55+, configurations are written in Lua. This setup uses a modular design loaded via `hyprland.lua`:

- **[hyprland.lua](.config/hypr/hyprland.lua)**: The main entry point configuration.
- **[binds.lua](.config/hypr/binds.lua)**: Keybindings and window actions.
- **[lookandfeel.lua](.config/hypr/lookandfeel.lua)**: Theme, window decorations, animations, and layouts.
- **[monitors.lua](.config/hypr/monitors.lua)**: Multi-monitor positioning and scaling.
- **[autostart.lua](.config/hypr/autostart.lua)**: Background daemons and initial processes.
- Other modular configurations include `aliases.lua`, `enviroment-variables.lua`, `permissions.lua`, `windows-and-workspaces.lua`, and `workspaces.lua`.

> [!NOTE]
> All legacy `.conf` configuration files for Hyprland have been completely removed from this repository in favor of native `.lua` configuration. The configuration parameters (like `terminal`, `fileManager`, and `menu`) are defined globally in `aliases.lua` to be dynamically referenced as Lua variables inside keybindings (`binds.lua`).

## Neovim Configuration (Micro-like)

The Neovim configuration in [.config/nvim](.config/nvim) is preconfigured to mimic the intuitive keybindings and workflow of the Micro editor, while keeping all the power of Neovim under the hood.

- **Familiar Keybindings**: Standard shortcuts for save (`Ctrl+S`), quit (`Ctrl+Q`), open file (`Ctrl+O`), search (`Ctrl+F`), selection (`Shift+Arrows`, `Ctrl+A`), clipboard (`Ctrl+C`, `Ctrl+V`, `Ctrl+X`), tabs (`Ctrl+T` new buffer, `Ctrl+W` close buffer, `Alt+,`/`Alt+.` switch buffers), and terminal (`Ctrl+B`).
- **File Explorer Sidebar**: Press `Ctrl+H` to toggle the Neo-tree sidebar.
- **Fuzzy Finder**: Press `Ctrl+O` to search files in the workspace via Telescope.
- **Visuals**: Uses the Catppuccin Macchiato colorscheme by default to match the overall system style, paired with `lualine` for status bar info.



