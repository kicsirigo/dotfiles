#!/bin/bash
capacity=$(cat /sys/class/power_supply/BAT0/capacity)
status=$(cat /sys/class/power_supply/BAT0/status)
# A hátralévő idő kinyerése (acpi parancs kell hozzá: sudo pacman -S acpi)
remaining=$(acpi -b | grep -oP '\d+:\d+:\d+(?= remaining| until charged)')

if [ "$status" = "Charging" ]; then
    icon=""
else
    if [ "$capacity" -gt 90 ]; then icon="";
    elif [ "$capacity" -gt 60 ]; then icon="";
    elif [ "$capacity" -gt 40 ]; then icon="";
    elif [ "$capacity" -gt 15 ]; then icon="";
    else icon=""; fi
fi

# Ha a 'time' paramétert kapja, az időt küldi, egyébként a százalékot
if [ "$1" = "time" ]; then
    echo "$remaining"
else
    echo "$capacity% $icon"
fi