#!/usr/bin/env bash
set -euo pipefail

NODES=(cp1 cp2 cp3 w1 w2)

for n in "${NODES[@]}"; do
  limactl stop "$n" >/dev/null 2>&1 || true
done

limactl delete -f "${NODES[@]}" >/dev/null 2>&1 || true
limactl prune >/dev/null 2>&1 || true

limactl start --tty=false --name=cp1 lima/cp1.yaml
limactl start --tty=false --name=cp2 lima/cp2.yaml
limactl start --tty=false --name=cp3 lima/cp3.yaml
limactl start --tty=false --name=w1 lima/w1.yaml
limactl start --tty=false --name=w2 lima/w2.yaml
