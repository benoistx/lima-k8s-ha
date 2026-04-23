#!/usr/bin/env bash
set -euo pipefail

echo "Worker join command:"
limactl shell cp1 kubeadm token create --print-join-command

echo
echo "Control-plane certificate key:"
limactl shell cp1 sudo kubeadm init phase upload-certs --upload-certs | tail -n 1
