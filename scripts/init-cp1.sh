#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sudo kubeadm init \
  --control-plane-endpoint 192.168.105.3:6443 \
  --apiserver-advertise-address 192.168.105.3 \
  --pod-network-cidr 10.244.0.0/16 \
  --upload-certs
