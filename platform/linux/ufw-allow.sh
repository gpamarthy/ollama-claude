#!/bin/sh
# Open port 11434 to a specific CIDR via the user's firewall.
# Used by `oc install --topology split-host`. Idempotent.
#
# Usage: sudo platform/linux/ufw-allow.sh <CIDR>

set -eu

cidr="${1:-}"
if [ -z "$cidr" ]; then
  printf 'usage: %s <CIDR>\n' "$0" >&2
  exit 2
fi

# Validate CIDR shape (best-effort, no regex extension)
case "$cidr" in
  *.*.*.*/[0-9]*) : ;;
  *::*/*) : ;;
  *) printf 'invalid CIDR: %s\n' "$cidr" >&2; exit 2 ;;
esac

if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -qE "11434.*$cidr"; then
    printf '[ok] ufw rule already present for %s\n' "$cidr"
    exit 0
  fi
  ufw allow from "$cidr" to any port 11434 proto tcp
  printf '[ok] ufw rule added: 11434/tcp from %s\n' "$cidr"
  exit 0
fi

if command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --zone=trusted --add-source="$cidr"
  firewall-cmd --permanent --zone=trusted --add-port=11434/tcp
  firewall-cmd --reload
  printf '[ok] firewalld rule added\n'
  exit 0
fi

if command -v iptables >/dev/null 2>&1; then
  iptables -A INPUT -p tcp -s "$cidr" --dport 11434 -j ACCEPT
  printf '[ok] iptables rule added (NOT persisted across reboot)\n'
  exit 0
fi

printf '[warn] no firewall management tool found (ufw, firewall-cmd, iptables)\n' >&2
exit 1
