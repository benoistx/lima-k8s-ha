#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="
  limactl shell "$n" sh -c '
    printf "hostname: "
    hostname
    printf "lima0: "
    ip -4 addr show lima0 | awk "/inet / {print \$2}"
    printf "default: "
    ip route | awk "/default/ {print \$3, \$5; exit}" || true
    printf "containerd: "
    systemctl is-active containerd || true
    printf "kubeadm: "
    kubeadm version -o short || true
    printf "kubelet: "
    kubelet --version || true
  '
  echo
done
