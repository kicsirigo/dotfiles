#!/bin/bash

# Outputs yuck markup for a vertical list of available WiFi networks.
# Since `iw` is not available, approximate dBm from nmcli SIGNAL%:
# dBm ≈ (SIGNAL/2) - 100

wifi_state="$(/home/mate/.config/eww/scripts/wifi_radio.sh)"
if [ "$wifi_state" != "on" ]; then
  echo "(box :orientation \"v\" :space-evenly false)"
  exit 0
fi

lines=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes 2>/dev/null | head -n 20)

markup="(box :orientation \"v\" :space-evenly false :spacing 4"

if [ -z "$lines" ]; then
  markup="$markup (label :class \"wifi-empty\" :text \"No networks found.\")"
  markup="$markup)"
  echo "$markup"
  exit 0
fi

index=0
while IFS= read -r line; do
  inuse="${line%%:*}"
  rest="${line#*:}"
  ssid="${rest%%:*}"
  rest="${rest#*:}"
  signal="${rest%%:*}"
  security="${rest#*:}"

  # skip empty/whitespace-only SSIDs
  ssid_trimmed="$(printf '%s' "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$ssid_trimmed" ] && continue
  [ -z "$signal" ] && signal=0

  # sanitize double quotes in ssid
  ssid_safe="${ssid_trimmed//\"/\\\"}"

  dbm=$(( (signal / 2) - 100 ))
  if [ "$inuse" = "*" ]; then
    klass="wifi-item active"
    prefix=""
  else
    klass="wifi-item"
    prefix="  "
  fi

  if [ -n "$security" ] && [ "$security" != "--" ]; then
    lock_icon=""
  else
    lock_icon=""
  fi

  markup="$markup (eventbox :onclick \"bash -lc '/home/mate/.config/eww/scripts/wifi_select.sh ${index}'\"
    (box :class \"$klass\" :orientation \"h\" :space-evenly false
      (label :class \"wifi-prefix\" :text \"$prefix\")
      (label :class \"wifi-lock\" :text \"$lock_icon\")
      (label :class \"wifi-ssid\" :text \"$ssid_safe\")
      (box :hexpand true)
      (label :class \"wifi-dbm\" :text \"${dbm} dBm\")
    ))"
  index=$((index + 1))
done <<< "$lines"

markup="$markup)"
echo "$markup"

