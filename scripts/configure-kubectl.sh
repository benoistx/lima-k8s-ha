#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl get nodes -o wide || true
'
