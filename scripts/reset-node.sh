#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <node>"
  exit 1
fi

NODE="$1"

limactl shell "$NODE" sh -c '
  set -eux
  sudo kubeadm reset -f || true
  sudo systemctl restart containerd kubelet || true
'
