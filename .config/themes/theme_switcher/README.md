# Theme Switcher

Switches between:

- `~/.config/themes/catppuccin_macchiato`
- `~/.config/themes/catppuccin_latte`
- `~/.config/themes/nord`

All switcher files live in `~/.config/themes/theme_switcher`.

## Files

- `theme_switcher.sh` - main script
- `current_theme` - state file created automatically
- `backups/` - backups of non-symlink config files replaced during switch

## Usage

```bash
~/.config/themes/theme_switcher/theme_switcher.sh toggle
~/.config/themes/theme_switcher/theme_switcher.sh catppuccin_macchiato
~/.config/themes/theme_switcher/theme_switcher.sh catppuccin_latte
~/.config/themes/theme_switcher/theme_switcher.sh nord
~/.config/themes/theme_switcher/theme_switcher.sh menu
~/.config/themes/theme_switcher/theme_switcher.sh current
```

## Optional Hyprland binds

Add to your Hyprland config:

```ini
bind = SUPER, T, exec, ~/.config/themes/theme_switcher/theme_switcher.sh toggle
bind = SUPER SHIFT, T, exec, ~/.config/themes/theme_switcher/theme_switcher.sh menu
```

Then reload Hyprland:

```bash
hyprctl reload
```
