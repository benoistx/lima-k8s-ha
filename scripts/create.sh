#!/usr/bin/env bash
set -euo pipefail

NODES=(cp1 cp2 cp3 w1 w2)

echo "Stopping running instances..."
for n in "${NODES[@]}"; do
  limactl stop "$n" >/dev/null 2>&1 || true
done

echo "Deleting instances..."
limactl delete -f "${NODES[@]}" >/dev/null 2>&1 || true

echo "Pruning Lima..."
limactl prune >/dev/null 2>&1 || true

echo "Cleaning stale host-side processes..."
pkill -f 'limactl shell .*apt-get' || true
pkill -f '/usr/bin/ssh .*apt-get' || true
pkill -f 'ssh.*\.lima/.*/ssh\.sock' || true
pkill -f 'limactl hostagent.*cp[123]' || true
pkill -f 'limactl hostagent.*w[12]' || true
sudo pkill -f socket_vmnet || true

echo "Removing stale ssh sockets..."
find ~/.lima -name ssh.sock -type s -print -delete 2>/dev/null || true
find ~/.lima -name ssh.sock -type f -print -delete 2>/dev/null || true

echo "Cleaning generated artifacts in ~/.lima..."
rm -f ~/.lima/bootstrap-*.log \
      ~/.lima/setup-*.log \
      ~/.lima/k8s-setup-*.log \
      ~/.lima/prep-*.log \
      ~/.lima/cp*.yaml \
      ~/.lima/w*.yaml \
      ~/.lima/ubuntu-24.04-k8s.yaml 2>/dev/null || true

echo "Starting instances non-interactively..."
limactl start --tty=false --name=cp1 lima/cp1.yaml
limactl start --tty=false --name=cp2 lima/cp2.yaml
limactl start --tty=false --name=cp3 lima/cp3.yaml
limactl start --tty=false --name=w1 lima/w1.yaml
limactl start --tty=false --name=w2 lima/w2.yaml

echo "Done."
