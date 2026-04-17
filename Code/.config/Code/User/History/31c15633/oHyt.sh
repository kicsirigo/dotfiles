#!/bin/bash
# Alapértékek
capacity=$(cat /sys/class/power_supply/BAT0/capacity)
status=$(cat /sys/class/power_supply/BAT0/status)

# Ikon meghatározása
if [ "$status" = "Charging" ]; then
    icon=""
else
    if [ "$capacity" -gt 90 ]; then icon="";
    elif [ "$capacity" -gt 60 ]; then icon="";
    elif [ "$capacity" -gt 40 ]; then icon="";
    elif [ "$capacity" -gt 15 ]; then icon="";
    else icon=""; fi
fi

remaining=$(acpi -b | grep -oP '\d+:\d+(?=:\d+ remaining|:\d+ until charged)' || echo "N/A")

if [ "$1" = "time" ]; then
    echo "   $remaining"
else
    echo "$capacity% $icon"
fi