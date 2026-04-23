#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
  (
    echo "=== $n ==="
    limactl shell "$n" sh -c '
      set -eux
      export DEBIAN_FRONTEND=noninteractive

      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl gpg containerd

      sudo mkdir -p /etc/containerd
      containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
      sudo sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml
      sudo systemctl enable --now containerd
      sudo systemctl restart containerd

      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
        | sudo gpg --dearmor --batch --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
      sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

      sudo apt-get update
      sudo apt-get install -y kubelet kubeadm kubectl
      sudo apt-mark hold kubelet kubeadm kubectl

      printf "containerd: "
      systemctl is-active containerd
      printf "kubeadm: "
      kubeadm version -o short
    '
  ) >"bootstrap-$n.log" 2>&1 &
done

wait

echo "Bootstrap complete"
echo "Inspect with: for n in cp1 cp2 cp3 w1 w2; do printf \"===== %s =====\\n\" \"\$n\"; tail -n 30 \"bootstrap-\$n.log\"; echo; done"
