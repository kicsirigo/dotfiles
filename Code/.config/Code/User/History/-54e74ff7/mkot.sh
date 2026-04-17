#!/usr/bin/env bash
set -u

SUBNET_PREFIX="10.103.89"

IP_TO_ADD="10.103.4.21"

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"

for i in {1..254}; do
  host="${SUBNET_PREFIX}.${i}"
  echo "Checking ${host} ..."

  if ! ping -c 5 -W 1 "${host}" >/dev/null 2>&1; then
    echo "  Host down after 5 pings, skipping."
    continue
  fi

  echo "  Host is up."

  # 2) If host is up, check if /etc/cups/cupsd.conf exists
  if ssh ${SSH_OPTS} "${host}" 'test -f /etc/cups/cupsd.conf'; then
    echo "  /etc/cups/cupsd.conf exists."

    # 3) Append IP only if not already present (append-only, no deletion)
    ssh ${SSH_OPTS} "${host}" "grep -qxF '${IP_TO_ADD}' /etc/cups/cupsd.conf || echo '${IP_TO_ADD}' | sudo tee -a /etc/cups/cupsd.conf >/dev/null"

    if [ $? -eq 0 ]; then
      echo "  Ensured ${IP_TO_ADD} is present."
    else
      echo "  Failed to update ${host} (permissions/ssh issue)."
    fi
  else
    echo "  /etc/cups/cupsd.conf does not exist, skipping host."
  fi
done

echo "Done."