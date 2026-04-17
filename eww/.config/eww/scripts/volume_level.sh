#!/bin/bash

get_volume() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '
        {
            if ($3 == "[MUTED]") {
                print 0
            } else {
                print int(($2 * 100) + 0.5)
            }
        }
    '
}

if [ "$1" = "--once" ]; then
    get_volume
    exit 0
fi

get_volume
wpctl subscribe | while read -r _; do
    get_volume
done
