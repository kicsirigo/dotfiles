#!/bin/bash
capacity=$(cat /sys/class/power_supply/BAT0/capacity)
status=$(cat /sys/class/power_supply/BAT0/status)

if [ "$status" = "Charging" ]; then
    icon=""
else
    if [ "$capacity" -gt 90 ]; then icon="";
    elif [ "$capacity" -gt 60 ]; then icon="";
    elif [ "$capacity" -gt 40 ]; then icon="";
    elif [ "$capacity" -gt 15 ]; then icon="";
    else icon=""; fi
fi

raw_time=$(acpi -b | grep -oP '\d+:\d+(?=:)' || echo "")

if [ -n "$raw_time" ]; then
    hours=$(echo $raw_time | cut -d: -f1 | sed 's/^0//')
    minutes=$(echo $raw_time | cut -d: -f2 | sed 's/^0//')
    [ -z "$hours" ] && hours="0"
    [ -z "$minutes" ] && minutes="0"
    pretty_time="${hours} h ${minutes} min"
else
    pretty_time="Full"
fi

if [ "$1" = "time" ]; then
    if [ "$status" = "Full" ] || [ "$status" = "Not charging" ] && [ "$capacity" -eq 100 ]; then
        echo "   Full"
    else
        echo "   $pretty_time"
    fi
else
    echo "$capacity% $icon"
fi