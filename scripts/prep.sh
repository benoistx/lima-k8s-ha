#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
  (
    echo "=== $n ==="
    limactl shell "$n" sh -c '
      set -eux

      sudo swapoff -a
      sudo sed -i.bak "/ swap / s/^/#/" /etc/fstab

      cat <<EOS | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOS

      sudo modprobe overlay
      sudo modprobe br_netfilter

      cat <<EOS | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOS

      sudo sysctl --system >/dev/null
    '
  ) >"prep-$n.log" 2>&1 &
done

wait

limactl shell cp1 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.3 | sudo tee /etc/default/kubelet'
limactl shell cp2 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.4 | sudo tee /etc/default/kubelet'
limactl shell cp3 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.5 | sudo tee /etc/default/kubelet'
limactl shell w1  sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.11 | sudo tee /etc/default/kubelet'
limactl shell w2  sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.12 | sudo tee /etc/default/kubelet'

for n in cp1 cp2 cp3 w1 w2; do
  limactl shell "$n" sudo systemctl restart kubelet
done

echo "Prep complete"
echo "Inspect with: for n in cp1 cp2 cp3 w1 w2; do echo ===== \$n =====; tail -n 30 prep-\$n.log; echo; done"
