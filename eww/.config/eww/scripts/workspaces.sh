#!/bin/bash

active_workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')
workspace_ids=$(hyprctl workspaces -j 2>/dev/null | jq -r '.[].id' | sort -n)

if [ -z "$workspace_ids" ]; then
    workspace_ids="$active_workspace"
fi

markup="(box :orientation \"h\" :space-evenly false :spacing 10 :valign \"center\""

for id in $workspace_ids; do
    if [ "$id" -lt 1 ]; then
        continue
    fi

    if [ "$id" = "$active_workspace" ]; then
        icon="●"
        klass="workspace-icon active"
    else
        icon="○"
        klass="workspace-icon"
    fi

    markup="$markup (eventbox :onclick \"hyprctl dispatch workspace $id\" (label :class \"$klass\" :text \"$icon\"))"
done

markup="$markup)"
printf '%s\n' "$markup"
