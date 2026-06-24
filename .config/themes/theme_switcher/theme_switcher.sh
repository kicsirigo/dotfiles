#!/usr/bin/env bash

set -euo pipefail

THEME_ROOT_MACCHIATO="${HOME}/.config/themes/catppuccin_macchiato"
THEME_ROOT_LATTE="${HOME}/.config/themes/catppuccin_latte"
THEME_ROOT_NORD="${HOME}/.config/themes/nord"
TARGET_CONFIG_DIR="${HOME}/.config"
SWITCHER_DIR="${HOME}/.config/themes/theme_switcher"
STATE_FILE="${SWITCHER_DIR}/current_theme"
BACKUP_ROOT="${SWITCHER_DIR}/backups"

SPINNER_FRAMES='|/-\'

mkdir -p "${SWITCHER_DIR}" "${BACKUP_ROOT}"

notify() {
  if [ -n "${TEST_SANDBOX_HOME:-}" ] || [ -n "${TEST_MODE:-}" ]; then
    return 0
  fi
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Theme Switcher" "${title}" "${body}" || true
  fi
}

animated_step() {
  local message="$1"
  local duration_ms="${2:-420}"
  local frame_count="${#SPINNER_FRAMES}"
  local iterations=$(( duration_ms / 60 ))
  local i=0
  while [ "${i}" -lt "${iterations}" ]; do
    local idx=$(( i % frame_count ))
    printf "\r[%c] %s" "${SPINNER_FRAMES:${idx}:1}" "${message}"
    sleep 0.06
    i=$(( i + 1 ))
  done
  printf "\r[+] %s\n" "${message}"
}

theme_root_for() {
  local theme="$1"
  case "${theme}" in
    catppuccin_macchiato|classic) echo "${THEME_ROOT_MACCHIATO}" ;;
    catppuccin_latte|frappe) echo "${THEME_ROOT_LATTE}" ;;
    nord) echo "${THEME_ROOT_NORD}" ;;
    *)
      echo "Unknown theme: ${theme}" >&2
      exit 1
      ;;
  esac
}

detect_current_theme() {
  if [ -f "${STATE_FILE}" ]; then
    local current
    current="$(<"${STATE_FILE}")"
    if [ "${current}" = "catppuccin_macchiato" ] || [ "${current}" = "catppuccin_latte" ] || [ "${current}" = "nord" ]; then
      echo "${current}"
      return
    fi
    if [ "${current}" = "classic" ]; then
      echo "catppuccin_macchiato"
      return
    fi
    if [ "${current}" = "frappe" ]; then
      echo "catppuccin_latte"
      return
    fi
  fi

  local hypr_link="${TARGET_CONFIG_DIR}/hypr"
  if [ -L "${hypr_link}" ]; then
    local target
    target="$(readlink -f "${hypr_link}")"
    case "${target}" in
      "${THEME_ROOT_MACCHIATO}"/*) echo "catppuccin_macchiato"; return ;;
      "${THEME_ROOT_LATTE}"/*) echo "catppuccin_latte"; return ;;
      "${THEME_ROOT_NORD}"/*) echo "nord"; return ;;
    esac
  fi

  echo "catppuccin_macchiato"
}

pick_next_theme() {
  local current="$1"
  case "${current}" in
    catppuccin_macchiato) echo "catppuccin_latte" ;;
    catppuccin_latte) echo "nord" ;;
    *) echo "catppuccin_macchiato" ;;
  esac
}

collect_config_entries() {
  local source_root="$1"
  local module_path
  for module_path in "${source_root}"/*; do
    [ -d "${module_path}/.config" ] || continue
    local entry
    for entry in "${module_path}/.config"/*; do
      [ -e "${entry}" ] || continue
      basename "${entry}"
    done
  done | sort -u
}

link_one_entry() {
  local source_root="$1"
  local entry_name="$2"
  local backup_dir="$3"
  local source_path=""
  local module_path

  for module_path in "${source_root}"/*; do
    if [ -e "${module_path}/.config/${entry_name}" ]; then
      source_path="${module_path}/.config/${entry_name}"
      break
    fi
  done

  [ -n "${source_path}" ] || return 0

  local target_path="${TARGET_CONFIG_DIR}/${entry_name}"

  if [ "${entry_name}" = "gtk-3.0" ] || [ "${entry_name}" = "gtk-4.0" ]; then
    if [ -L "${target_path}" ]; then
      rm -f "${target_path}"
    fi
    if [ -f "${target_path}" ]; then
      rm -f "${target_path}"
    fi
    mkdir -p "${target_path}"
    local item
    for item in "${source_path}"/*; do
      [ -e "${item}" ] || continue
      local base_item
      base_item="$(basename "${item}")"
      if [ "${base_item}" = "settings.ini" ]; then
        if [ ! -e "${target_path}/${base_item}" ]; then
          cp "${item}" "${target_path}/${base_item}"
        fi
      else
        cp -r "${item}" "${target_path}/"
      fi
    done
    return 0
  fi

  if [ -L "${target_path}" ] || [ -f "${target_path}" ] || [ -d "${target_path}" ]; then
    if [ -L "${target_path}" ]; then
      rm -f "${target_path}"
    else
      mkdir -p "${backup_dir}"
      mv "${target_path}" "${backup_dir}/${entry_name}"
    fi
  fi

  ln -s "${source_path}" "${target_path}"
}

refresh_desktop() {
  if [ -n "${TEST_SANDBOX_HOME:-}" ] || [ -n "${TEST_MODE:-}" ]; then
    echo "Test mode detected: skipping visual transition and daemon reloads."
    return 0
  fi

  animated_step "Applying visual transition"

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
  fi

  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 waybar >/dev/null 2>&1 || true
  fi

  if command -v swaync-client >/dev/null 2>&1; then
    swaync-client -R >/dev/null 2>&1 || true
    swaync-client -rs >/dev/null 2>&1 || true
  fi

  if pgrep -x xsettingsd >/dev/null 2>&1; then
    pkill -HUP xsettingsd >/dev/null 2>&1 || true
  fi

  local wallpaper_link="${TARGET_CONFIG_DIR}/wallpaper_arch.png"
  if command -v awww >/dev/null 2>&1 && [ -e "${wallpaper_link}" ]; then
    if ! pgrep -x awww-daemon >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
      awww-daemon >/dev/null 2>&1 &
      sleep 0.2
    fi
    awww img "${wallpaper_link}" \
      --transition-type grow \
      --transition-pos 0.5,0.5 >/dev/null 2>&1 || true
  fi
}

apply_app_integrations() {
  local target_theme="$1"
  local code_theme code_icon firefox_theme_id firefox_content_theme darkreader_enabled

  if [ "${target_theme}" = "catppuccin_latte" ]; then
    code_theme="Catppuccin Latte"
    code_icon="catppuccin-latte"
    firefox_theme_id="firefox-compact-light@mozilla.org"
    firefox_content_theme=1
    darkreader_enabled="false"
  elif [ "${target_theme}" = "nord" ]; then
    code_theme="Nord"
    code_icon="catppuccin-macchiato"
    firefox_theme_id="firefox-compact-dark@mozilla.org"
    firefox_content_theme=0
    darkreader_enabled="true"
  else
    code_theme="Catppuccin Macchiato"
    code_icon="catppuccin-macchiato"
    firefox_theme_id="{15cb5e64-94bd-41aa-91cf-751bb1a84972}"
    firefox_content_theme=0
    darkreader_enabled="true"
  fi

  CODE_THEME="${code_theme}" CODE_ICON="${code_icon}" python3 - <<'PY'
import json
import os
from pathlib import Path

theme = os.environ["CODE_THEME"]
icon = os.environ["CODE_ICON"]

for p in [
    Path.home() / ".config/Code/User/settings.json",
    Path.home() / ".config/Cursor/User/settings.json",
]:
    p.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if p.exists():
      try:
        data = json.loads(p.read_text())
      except Exception:
        data = {}
    data["workbench.colorTheme"] = theme
    data["workbench.iconTheme"] = icon
    p.write_text(json.dumps(data, indent=4) + "\n")
PY

  FIREFOX_THEME_ID="${firefox_theme_id}" FIREFOX_CONTENT_THEME="${firefox_content_theme}" DARKREADER_ENABLED="${darkreader_enabled}" python3 - <<'PY'
import configparser
import json
import os
import re
import sqlite3
from pathlib import Path

home = Path.home()
profiles_ini = home / ".config/mozilla/firefox/profiles.ini"
if not profiles_ini.exists():
    raise SystemExit(0)

cfg = configparser.ConfigParser()
cfg.read(profiles_ini)
profile_rel = None
for section in cfg.sections():
    if section.startswith("Install") and cfg.get(section, "Default", fallback=""):
        profile_rel = cfg.get(section, "Default")
        break
if profile_rel is None:
    for section in cfg.sections():
        if section.startswith("Profile") and cfg.get(section, "Default", fallback="0") == "1":
            profile_rel = cfg.get(section, "Path", fallback=None)
            break
if not profile_rel:
    raise SystemExit(0)

profile = home / ".config/mozilla/firefox" / profile_rel
if not profile.exists():
    raise SystemExit(0)

theme_id = os.environ["FIREFOX_THEME_ID"]
content_theme = os.environ["FIREFOX_CONTENT_THEME"]
darkreader_enabled = os.environ["DARKREADER_ENABLED"].lower() == "true"

# Persist desired Firefox theme via user.js so it survives running instance writes.
user_js = profile / "user.js"
existing = user_js.read_text() if user_js.exists() else ""
lines = [ln for ln in existing.splitlines() if not re.match(r'user_pref\("(extensions.activeThemeID|browser.theme.content-theme|browser.theme.toolbar-theme)"', ln)]
lines.append(f'user_pref("extensions.activeThemeID", "{theme_id}");')
lines.append(f'user_pref("browser.theme.content-theme", {content_theme});')
lines.append(f'user_pref("browser.theme.toolbar-theme", {content_theme});')
user_js.write_text("\n".join(lines).strip() + "\n")

# Also patch prefs.js for immediate effect when Firefox is not running.
prefs_js = profile / "prefs.js"
if prefs_js.exists():
    prefs_text = prefs_js.read_text()
    for key, value in [
        ("extensions.activeThemeID", f'"{theme_id}"'),
        ("browser.theme.content-theme", content_theme),
        ("browser.theme.toolbar-theme", content_theme),
    ]:
        pattern = rf'user_pref\("{re.escape(key)}",\s*.*?\);'
        replacement = f'user_pref("{key}", {value});'
        if re.search(pattern, prefs_text):
            prefs_text = re.sub(pattern, replacement, prefs_text)
        else:
            prefs_text += "\n" + replacement
    prefs_js.write_text(prefs_text)

# Update Dark Reader global enabled state in extension sync storage.
db = profile / "storage-sync-v2.sqlite"
if db.exists():
    conn = sqlite3.connect(db)
    try:
        row = conn.execute("SELECT data FROM storage_sync_data WHERE ext_id = ?", ("addon@darkreader.org",)).fetchone()
        if row and row[0]:
            data = json.loads(row[0])
            data["enabled"] = darkreader_enabled
            data["enabledByDefault"] = darkreader_enabled
            conn.execute(
                "UPDATE storage_sync_data SET data = ?, sync_change_counter = sync_change_counter + 1 WHERE ext_id = ?",
                (json.dumps(data, separators=(",", ":")), "addon@darkreader.org"),
            )
            conn.commit()
    finally:
        conn.close()
PY
}

apply_gtk_integrations() {
  local target_theme="$1"
  local gtk_theme=""

  case "${target_theme}" in
    catppuccin_macchiato) gtk_theme="catppuccin-macchiato-lavender-standard+default" ;;
    catppuccin_latte) gtk_theme="catppuccin-latte-lavender-standard+default" ;;
    nord) gtk_theme="Nordic" ;;
    *)
      echo "Unknown theme for GTK mapping: ${target_theme}" >&2
      exit 1
      ;;
  esac

  # Update settings.ini files for GTK 3.0 and GTK 4.0
  GTK_THEME="${gtk_theme}" python3 - <<'PY'
import os
from pathlib import Path

gtk_theme = os.environ["GTK_THEME"]

def update_gtk_settings(file_path):
    path = Path(file_path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    
    lines = []
    if path.exists():
        lines = path.read_text().splitlines()
        
    settings_index = -1
    for idx, line in enumerate(lines):
        if line.strip() == "[Settings]":
            settings_index = idx
            break
            
    theme_line_index = -1
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("gtk-theme-name") and "=" in stripped:
            theme_line_index = idx
            break
            
    new_line = f"gtk-theme-name = {gtk_theme}"
    
    if settings_index != -1:
        if theme_line_index != -1:
            lines[theme_line_index] = new_line
        else:
            lines.insert(settings_index + 1, new_line)
    else:
        if theme_line_index != -1:
            lines[theme_line_index] = new_line
        else:
            lines.insert(0, new_line)
        lines.insert(0, "[Settings]")
        
    path.write_text("\n".join(lines).strip() + "\n")

update_gtk_settings("~/.config/gtk-3.0/settings.ini")
update_gtk_settings("~/.config/gtk-4.0/settings.ini")
PY

  # Update active session via gsettings
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "${gtk_theme}" || true
  else
    echo "gsettings not available, skipping session theme update" >&2
  fi
}

switch_theme() {
  local target_theme="$1"
  local source_root
  source_root="$(theme_root_for "${target_theme}")"

  if [ ! -d "${source_root}" ]; then
    echo "Theme root missing: ${source_root}" >&2
    exit 1
  fi

  local backup_dir="${BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)"
  local entries
  mapfile -t entries < <(collect_config_entries "${source_root}")

  if [ "${#entries[@]}" -eq 0 ]; then
    echo "No .config entries found in ${source_root}" >&2
    exit 1
  fi

  printf "\nSwitching theme to '%s'\n" "${target_theme}"
  animated_step "Collecting theme assets"

  local entry
  for entry in "${entries[@]}"; do
    animated_step "Linking ${entry}" 160
    link_one_entry "${source_root}" "${entry}" "${backup_dir}"
  done

  echo "${target_theme}" > "${STATE_FILE}"
  apply_app_integrations "${target_theme}"
  apply_gtk_integrations "${target_theme}"

  # Update wallpaper symlink
  local theme_wallpaper="${source_root}/wallpaper_arch.png"
  if [ -f "${theme_wallpaper}" ] || [ -L "${theme_wallpaper}" ]; then
    rm -f "${TARGET_CONFIG_DIR}/wallpaper_arch.png"
    ln -s "${theme_wallpaper}" "${TARGET_CONFIG_DIR}/wallpaper_arch.png"
  fi

  refresh_desktop

  notify "Theme switched" "Now using: ${target_theme}"
  printf "\nDone. Active theme: %s\n" "${target_theme}"
}

menu_select_theme() {
  local prompt="Select theme"
  local selected=""

  if command -v rofi >/dev/null 2>&1; then
    local macchiato_img="${HOME}/.config/themes/catppuccin_macchiato/misc-config/.config/wallpaper_arch.png"
    local latte_img="${HOME}/.config/themes/catppuccin_latte/misc-config/.config/arch_pink.png"
    local nord_img="${HOME}/.config/themes/nord/archlinux.png"

    # Format the inputs for rofi dmenu with icons
    local rofi_input=""
    rofi_input+="Catppuccin Macchiato\x00icon\x1f${macchiato_img}\n"
    rofi_input+="Catppuccin Latte\x00icon\x1f${latte_img}\n"
    rofi_input+="Nord\x00icon\x1f${nord_img}\n"

    selected="$(echo -en "${rofi_input}" | rofi -dmenu -i -p "${prompt}" -show-icons -theme "${HOME}/.config/themes/theme_switcher/theme-menu.rasi" -hover-select -me-select-entry '' -me-accept-entry MousePrimary)"
  elif command -v fuzzel >/dev/null 2>&1; then
    selected="$(printf "catppuccin_macchiato\ncatppuccin_latte\nnord\n" | fuzzel --dmenu -p "${prompt}")"
  elif command -v wofi >/dev/null 2>&1; then
    selected="$(printf "catppuccin_macchiato\ncatppuccin_latte\nnord\n" | wofi --dmenu --prompt "${prompt}")"
  else
    echo "No launcher found (rofi/fuzzel/wofi). Use CLI arg instead." >&2
    exit 1
  fi

  case "${selected}" in
    "Catppuccin Macchiato"*) switch_theme "catppuccin_macchiato" ;;
    "Catppuccin Latte"*) switch_theme "catppuccin_latte" ;;
    "Nord"*) switch_theme "nord" ;;
    *)
      case "${selected}" in
        catppuccin_macchiato|catppuccin_latte|nord) switch_theme "${selected}" ;;
        *) echo "Selection cancelled: '${selected}'" ;;
      esac
      ;;
  esac
}

print_help() {
  cat <<'EOF'
Theme Switcher

Usage:
  theme_switcher.sh toggle                # cycle macchiato -> latte -> nord
  theme_switcher.sh catppuccin_macchiato  # force macchiato
  theme_switcher.sh catppuccin_latte      # force latte
  theme_switcher.sh nord                  # force nord
  theme_switcher.sh menu          # pick theme using launcher
  theme_switcher.sh current       # print detected current theme
  theme_switcher.sh classic|frappe # legacy aliases
EOF
}

main() {
  local cmd="${1:-toggle}"
  local current
  current="$(detect_current_theme)"

  case "${cmd}" in
    toggle) switch_theme "$(pick_next_theme "${current}")" ;;
    catppuccin_macchiato|classic) switch_theme "catppuccin_macchiato" ;;
    catppuccin_latte|frappe) switch_theme "catppuccin_latte" ;;
    nord) switch_theme "nord" ;;
    menu) menu_select_theme ;;
    current) echo "${current}" ;;
    -h|--help|help) print_help ;;
    *)
      echo "Unknown command: ${cmd}" >&2
      print_help
      exit 1
      ;;
  esac
}

main "${@}"
