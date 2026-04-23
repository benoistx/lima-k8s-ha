#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A
'
