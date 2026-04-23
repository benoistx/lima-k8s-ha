#!/usr/bin/env bash
set -euo pipefail

HOSTS_CONTENT="192.168.105.3 cp1
192.168.105.4 cp2
192.168.105.5 cp3
192.168.105.11 w1
192.168.105.12 w2"

for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="

  # Remove previous entries
  limactl shell "$n" sudo sed -i '/cp1\|cp2\|cp3\|w1\|w2/d' /etc/hosts

  # Add fresh entries
  echo "$HOSTS_CONTENT" | limactl shell "$n" sudo tee -a /etc/hosts >/dev/null

  # ✅ Validation (strict)
  echo "Check:"
  limactl shell "$n" sh -c '
    grep -q "192.168.105.3 cp1" /etc/hosts &&
    grep -q "192.168.105.4 cp2" /etc/hosts &&
    grep -q "192.168.105.5 cp3" /etc/hosts &&
    grep -q "192.168.105.11 w1" /etc/hosts &&
    grep -q "192.168.105.12 w2" /etc/hosts
  '

  # If we reach here → all checks passed
  limactl shell "$n" grep -E "cp1|cp2|cp3|w1|w2" /etc/hosts

  echo "OK"
  echo
done
