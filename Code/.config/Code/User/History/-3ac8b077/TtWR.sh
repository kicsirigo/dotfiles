#!/usr/bin/env bash
set -u

HOST="10.103.89.96"

IP_TO_ADD="10.103.4.21"

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"

echo "Checking ${HOST} ..."

if ! ping -c 5 -W 1 "${HOST}" >/dev/null 2>&1; then
  echo "Host down after 5 pings, skipping."
  exit 0
fi

echo "Host is up."

if ssh ${SSH_OPTS} "${HOST}" 'test -f /etc/cups/cupsd.conf'; then
  echo "/etc/cups/cupsd.conf exists."

  ssh ${SSH_OPTS} "${HOST}" \
    "grep -qxF '${IP_TO_ADD}' /etc/cups/cupsd.conf || echo '${IP_TO_ADD}' | sudo tee -a /etc/cups/cupsd.conf >/dev/null"

  if [ $? -eq 0 ]; then
    echo "Ensured ${IP_TO_ADD} is present."
  else
    echo "Failed to update ${HOST} (permissions/ssh issue)."
  fi
else
  echo "/etc/cups/cupsd.conf does not exist, skipping host."
fi

echo "Done."