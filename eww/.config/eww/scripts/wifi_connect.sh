#!/bin/bash

ssid="$1"
security="$2"
password="$3"

trimmed_ssid="$(printf '%s' "$ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
trimmed_security="$(printf '%s' "$security" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

if [ -z "$trimmed_ssid" ]; then
  eww -c /home/mate/.config/eww update wifi_connect_feedback="Select a network first."
  exit 1
fi

if [ -n "$trimmed_security" ] && [ "$trimmed_security" != "--" ] && [ "$trimmed_security" != "OPEN" ] && [ -z "$password" ]; then
  /home/mate/.config/eww/scripts/wifi_prompt_password.sh
  password="$(eww -c /home/mate/.config/eww get wifi_password 2>/dev/null)"
  if [ -z "$password" ]; then
    eww -c /home/mate/.config/eww update wifi_connect_feedback="Password is required."
    exit 1
  fi
fi

if [ -n "$trimmed_security" ] && [ "$trimmed_security" != "--" ] && [ "$trimmed_security" != "OPEN" ]; then
  output="$(nmcli --wait 10 dev wifi connect "$trimmed_ssid" password "$password" 2>&1)"
else
  output="$(nmcli --wait 10 dev wifi connect "$trimmed_ssid" 2>&1)"
fi

if [ $? -eq 0 ]; then
  eww -c /home/mate/.config/eww update \
    wifi_connect_feedback="Connected to ${trimmed_ssid}" \
    wifi_password=""
else
  short_error="$(printf '%s' "$output" | sed -n '1p' | cut -c1-80)"
  [ -z "$short_error" ] && short_error="Connection failed."
  eww -c /home/mate/.config/eww update wifi_connect_feedback="$short_error"
  exit 1
fi
