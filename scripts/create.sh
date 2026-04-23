#!/usr/bin/env bash
set -euo pipefail

NODES=(cp1 cp2 cp3 w1 w2)

# Stop running instances if any
for n in "${NODES[@]}"; do
  limactl stop "$n" >/dev/null 2>&1 || true
done

# Delete instances and prune
limactl delete -f "${NODES[@]}" >/dev/null 2>&1 || true
limactl prune >/dev/null 2>&1 || true

# Clean only our generated artifacts in ~/.lima (logs + yamls)
rm -f ~/.lima/bootstrap-*.log \
      ~/.lima/setup-*.log \
      ~/.lima/k8s-setup-*.log \
      ~/.lima/cp*.yaml \
      ~/.lima/w*.yaml \
      ~/.lima/ubuntu-24.04-k8s.yaml 2>/dev/null || true

# Start instances non-interactively
limactl start --tty=false --name=cp1 lima/cp1.yaml
limactl start --tty=false --name=cp2 lima/cp2.yaml
limactl start --tty=false --name=cp3 lima/cp3.yaml
limactl start --tty=false --name=w1 lima/w1.yaml
limactl start --tty=false --name=w2 lima/w2.yaml
