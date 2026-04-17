#!/bin/bash

index="$1"

if [ -z "$index" ]; then
  exit 1
fi

line="$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | sed -n "$((index + 1))p")"
if [ -z "$line" ]; then
  exit 1
fi

rest="${line#*:}"
ssid="${rest%%:*}"
rest="${rest#*:}"
rest="${rest#*:}"
security="${rest#*:}"

ssid_trimmed="$(printf '%s' "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
security_trimmed="$(printf '%s' "$security" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

eww -c /home/mate/.config/eww update \
  wifi_selected_ssid="$ssid_trimmed" \
  wifi_selected_security="$security_trimmed" \
  wifi_password="" \
  wifi_connect_feedback=""
