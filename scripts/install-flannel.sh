#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  kubectl get pods -A
'
