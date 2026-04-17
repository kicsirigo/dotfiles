#!/bin/bash

password=""

if command -v rofi >/dev/null 2>&1; then
  password="$(printf '' | rofi -dmenu -password -p 'WiFi password')"
elif command -v wofi >/dev/null 2>&1; then
  password="$(printf '' | wofi --dmenu --password --prompt 'WiFi password')"
elif command -v zenity >/dev/null 2>&1; then
  password="$(zenity --password --title='WiFi password' 2>/dev/null)"
else
  eww -c /home/mate/.config/eww update wifi_connect_feedback="No password prompt tool found."
  exit 1
fi

if [ -z "$password" ]; then
  eww -c /home/mate/.config/eww update wifi_connect_feedback="Password input cancelled."
  exit 1
fi

eww -c /home/mate/.config/eww update wifi_password="$password" wifi_connect_feedback="Password updated."
