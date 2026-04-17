#!/usr/bin/env bash

set -u

SUBNET_PREFIX="10.103.89"
USER="root"
IP_TO_ADD="10.103.4.21"
CONF="/etc/cups/cupsd.conf"

for i in {1..254}; do
  HOST="${SUBNET_PREFIX}.${i}"
  echo "Checking ${HOST} ..."

  if ! ping -c 5 -W 1 "$HOST" >/dev/null 2>&1; then
    echo "  Host down after 5 pings, skipping."
    continue
  fi

  echo "  Host is up."

  ssh -o ConnectTimeout=5 "${USER}@${HOST}" "bash -s" <<'EOF'
set -u
CONF="/etc/cups/cupsd.conf"
IP_TO_ADD="10.103.4.21"

if [ -f "$CONF" ]; then
  echo "  /etc/cups/cupsd.conf exists."
  if grep -qxF "$IP_TO_ADD" "$CONF"; then
    echo "  $IP_TO_ADD already present."
  else
    echo "$IP_TO_ADD" >> "$CONF"
    echo "  Added $IP_TO_ADD to $CONF."
  fi
else
  echo "  /etc/cups/cupsd.conf does not exist, skipping host."
fi
EOF
done

echo "Done."