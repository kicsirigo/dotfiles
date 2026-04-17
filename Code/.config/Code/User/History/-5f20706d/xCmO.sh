#!/bin/bash
get_brightness() {
    brightnessctl -m | cut -d, -f4 | tr -d '%'
}

get_brightness
while inotifywait -q -e modify /sys/class/backlight/*/brightness > /dev/null; do
    get_brightness
done
