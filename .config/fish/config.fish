# ~/.config/fish/config.fish
# Set up fish shell environment
set -g fish_color_normal normal
set -g fish_color_command cyan
set -g fish_color_error red
set -g fish_color_param yellow
set -g fish_color_comment green

# Enable vi mode
fish_vi_key_bindings

# Set prompt using starship (if installed)
if type -q starship
    starship init fish | source
end
