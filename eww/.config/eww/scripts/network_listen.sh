#!/bin/bash

field="$1"

emit() {
  case "$field" in
    --state|--icon|--text)
      /home/mate/.config/eww/scripts/network_status.sh "$field"
      ;;
    *)
      /home/mate/.config/eww/scripts/network_status.sh --state
      ;;
  esac
}

emit

# Emit again whenever NetworkManager reports changes
nmcli monitor 2>/dev/null | while read -r _; do
  emit
done

