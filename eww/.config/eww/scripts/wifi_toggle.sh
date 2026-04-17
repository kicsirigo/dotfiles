#!/bin/bash

current="$(/home/mate/.config/eww/scripts/wifi_radio.sh)"
if [ "$current" = "on" ]; then
  nmcli radio wifi off >/dev/null 2>&1 || true
  echo "off"
else
  nmcli radio wifi on >/dev/null 2>&1 || true
  echo "on"
fi

