#!/bin/bash

state="$(nmcli radio wifi 2>/dev/null | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
case "$state" in
  enabled|on|yes) echo "on" ;;
  *) echo "off" ;;
esac

