#!/usr/bin/env bash
set -euo pipefail

HOSTS_CONTENT="192.168.105.3 cp1
192.168.105.4 cp2
192.168.105.5 cp3
192.168.105.11 w1
192.168.105.12 w2"

for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="
  echo "$HOSTS_CONTENT" | limactl shell "$n" sudo tee -a /etc/hosts >/dev/null
  echo
done
