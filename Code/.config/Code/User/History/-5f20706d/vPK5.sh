#!/bin/bash
# Figyeli a fényerő fájl változását és azonnal kiírja az új értéket
get_brightness() {
    brightnessctl -m | cut -d, -f4 | tr -d '%'
}

get_brightness # Első indításkor kiírja
while inotifywait -e modify /sys/class/backlight/*/brightness; do
    get_brightness
done