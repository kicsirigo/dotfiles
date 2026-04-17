#!/bin/bash

get_profile() {
    powerprofilesctl get 2>/dev/null || echo "balanced"
}

cycle_profile() {
    current="$(get_profile)"
    case "$current" in
        performance) next="balanced" ;;
        balanced) next="power-saver" ;;
        power-saver) next="performance" ;;
        *) next="balanced" ;;
    esac

    powerprofilesctl set "$next" >/dev/null 2>&1 || true
    echo "$next"
}

set_profile() {
    powerprofilesctl set "$1" >/dev/null 2>&1 || true
}

case "$1" in
    --cycle)
        cycle_profile
        ;;
    --set)
        set_profile "$2"
        ;;
    *)
        get_profile
        ;;
esac
