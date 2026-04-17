#!/bin/bash

active_line=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$3=="connected"{print; exit}')

state="disconnected"
icon="󰌙"
text="Disconnected"

if [ -n "$active_line" ]; then
    device=$(printf '%s\n' "$active_line" | awk -F: '{print $1}')
    type=$(printf '%s\n' "$active_line" | awk -F: '{print $2}')
    connection=$(printf '%s\n' "$active_line" | awk -F: '{print $4}')

    if [ "$type" = "ethernet" ]; then
        state="connected"
        icon=""
        text="Wired"
    elif [ "$type" = "wifi" ]; then
        signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$device" 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')
        [ -z "$signal" ] && signal=0

        if [ "$signal" -lt 20 ]; then
            icon="󰤯"
        elif [ "$signal" -lt 40 ]; then
            icon="󰤟"
        elif [ "$signal" -lt 60 ]; then
            icon="󰤢"
        elif [ "$signal" -lt 80 ]; then
            icon="󰤥"
        else
            icon="󰤨"
        fi

        state="connected"
        text="${signal}%"
    elif [ -n "$connection" ]; then
        state="connected"
        icon="󰈀"
        text="$connection"
    else
        state="disabled"
        icon="󰤭"
        text="Off"
    fi
fi

case "$1" in
    --state) echo "$state" ;;
    --icon) echo "$icon" ;;
    --text) echo "$text" ;;
    *) printf '%s|%s|%s\n' "$state" "$icon" "$text" ;;
esac
