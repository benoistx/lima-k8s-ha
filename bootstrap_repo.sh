#!/usr/bin/env bash
set -euo pipefail

mkdir -p docs lima scripts k8s

mv cp*.yaml w*.yaml lima/ 2>/dev/null || true

cat > .gitignore <<'EOT'
.DS_Store
*.log
*.swp
*.tmp
kubeconfig
EOT

cat > scripts/create.sh <<'EOT'
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
EOT

cat > scripts/delete.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

limactl delete -f cp1 cp2 cp3 w1 w2
EOT

cat > scripts/hosts.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

HOSTS_CONTENT="192.168.105.3 cp1
192.168.105.4 cp2
192.168.105.5 cp3
192.168.105.11 w1
192.168.105.12 w2"

for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="

  limactl shell "$n" sudo sed -i '/cp1\|cp2\|cp3\|w1\|w2/d' /etc/hosts
  echo "$HOSTS_CONTENT" | limactl shell "$n" sudo tee -a /etc/hosts >/dev/null

  echo "Check:"
  limactl shell "$n" sh -c '
    grep -q "192.168.105.3 cp1" /etc/hosts &&
    grep -q "192.168.105.4 cp2" /etc/hosts &&
    grep -q "192.168.105.5 cp3" /etc/hosts &&
    grep -q "192.168.105.11 w1" /etc/hosts &&
    grep -q "192.168.105.12 w2" /etc/hosts
  '

  limactl shell "$n" grep -E "cp1|cp2|cp3|w1|w2" /etc/hosts
  echo "OK"
  echo
done
EOT

cat > scripts/bootstrap.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
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
  ' >"bootstrap-$n.log" 2>&1

done

echo "Bootstrap complete"
echo 'Run:'
echo 'for n in cp1 cp2 cp3 w1 w2; do'
echo '  printf "===== %s =====\n" "$n"'
echo '  tail -n 30 "bootstrap-$n.log"'
echo '  echo'
echo 'done'
EOT

cat > scripts/prep.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
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
  ' >"prep-$n.log" 2>&1

done

limactl shell cp1 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.3 | sudo tee /etc/default/kubelet'
limactl shell cp2 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.4 | sudo tee /etc/default/kubelet'
limactl shell cp3 sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.5 | sudo tee /etc/default/kubelet'
limactl shell w1  sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.11 | sudo tee /etc/default/kubelet'
limactl shell w2  sh -c 'echo KUBELET_EXTRA_ARGS=--node-ip=192.168.105.12 | sudo tee /etc/default/kubelet'

for n in cp1 cp2 cp3 w1 w2; do
  limactl shell "$n" sudo systemctl restart kubelet
done

echo "Prep complete"
echo 'Run:'
echo 'for n in cp1 cp2 cp3 w1 w2; do'
echo '  printf "===== %s =====\n" "$n"'
echo '  tail -n 30 "prep-$n.log"'
echo '  echo'
echo 'done'
EOT

cat > scripts/init-cp1.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sudo kubeadm init \
  --control-plane-endpoint 192.168.105.3:6443 \
  --apiserver-advertise-address 192.168.105.3 \
  --pod-network-cidr 10.244.0.0/16 \
  --upload-certs
EOT

cat > scripts/configure-kubectl.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  mkdir -p "$HOME/.kube"
  sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
  sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"
  kubectl --kubeconfig="$HOME/.kube/config" get nodes -o wide || true
'
EOT

cat > scripts/install-flannel.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A
'
EOT

cat > scripts/join-all.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

CONTROL_PLANES=(cp2 cp3)
WORKERS=(w1 w2)

WORKER_JOIN_CMD="$(limactl shell cp1 sudo kubeadm token create --print-join-command | tr -d '\r')"
CERT_KEY="$(limactl shell cp1 sudo kubeadm init phase upload-certs --upload-certs | tail -n 1 | tr -d '\r')"
CONTROL_PLANE_JOIN_CMD="${WORKER_JOIN_CMD} --control-plane --certificate-key ${CERT_KEY}"

for n in "${CONTROL_PLANES[@]}"; do
  echo "=== Joining control plane: ${n} ==="
  limactl shell "${n}" sudo kubeadm reset -f >/dev/null 2>&1 || true
  limactl shell "${n}" sudo sh -c "${CONTROL_PLANE_JOIN_CMD}"
  echo
done

for n in "${WORKERS[@]}"; do
  echo "=== Joining worker: ${n} ==="
  limactl shell "${n}" sudo kubeadm reset -f >/dev/null 2>&1 || true
  limactl shell "${n}" sudo sh -c "${WORKER_JOIN_CMD}"
  echo
done
EOT

cat > scripts/export-kubeconfig.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-kubeconfig}"
API_SERVER="192.168.105.3"

limactl shell cp1 sudo cat /etc/kubernetes/admin.conf > "$OUTPUT_FILE"
sed -i '' "s/127.0.0.1/${API_SERVER}/" "$OUTPUT_FILE"

echo "Use with:"
echo "  export KUBECONFIG=$PWD/${OUTPUT_FILE}"
echo "  kubectl get nodes -o wide"
EOT

cat > scripts/status.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="
  limactl shell "$n" sh -c '
    printf "hostname: "
    hostname
    printf "lima0: "
    ip -4 addr show lima0 | awk "/inet / {print \$2}"
    printf "default: "
    ip route | awk "/default/ {print \$3, \$5; exit}" || true
    printf "containerd: "
    systemctl is-active containerd || true
    printf "kubeadm: "
    kubeadm version -o short || true
    printf "kubelet: "
    kubelet --version || true
  '
  echo
done
EOT

cat > scripts/reset-node.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <node>"
  exit 1
fi

NODE="$1"

limactl shell "$NODE" sh -c '
  set -eux
  sudo kubeadm reset -f || true
  sudo systemctl restart containerd kubelet || true
'
EOT

cat > scripts/show-join-info.sh <<'EOT'
#!/usr/bin/env bash
set -euo pipefail

echo "Worker join command:"
limactl shell cp1 kubeadm token create --print-join-command

echo
echo "Control-plane certificate key:"
limactl shell cp1 sudo kubeadm init phase upload-certs --upload-certs | tail -n 1
EOT

cat > docs/architecture.md <<'EOT'
# Architecture

- cp1: 192.168.105.3
- cp2: 192.168.105.4
- cp3: 192.168.105.5
- w1: 192.168.105.11
- w2: 192.168.105.12

All nodes use Lima shared networking with static IPs on `lima0`.
EOT

cat > docs/bootstrap.md <<'EOT'
# Bootstrap Flow

1. `./scripts/create.sh`
2. `./scripts/hosts.sh`
3. `./scripts/bootstrap.sh`
4. `./scripts/prep.sh`
5. `./scripts/init-cp1.sh`
6. `./scripts/configure-kubectl.sh`
7. `./scripts/install-flannel.sh`
8. `./scripts/join-all.sh`
9. `./scripts/export-kubeconfig.sh`
10. `kubectl get nodes -o wide`
EOT

cat > docs/troubleshooting.md <<'EOT'
# Troubleshooting

## Check node state

```bash
./scripts/status.sh
```

## Check bootstrap logs

```bash
for n in cp1 cp2 cp3 w1 w2; do
  printf "===== %s =====\n" "$n"
  tail -n 50 "bootstrap-$n.log"
  echo
done
```

## Check prep logs

```bash
for n in cp1 cp2 cp3 w1 w2; do
  printf "===== %s =====\n" "$n"
  tail -n 50 "prep-$n.log"
  echo
done
```

## Reset a node

```bash
./scripts/reset-node.sh cp2
```
EOT

cat > k8s/kubeadm-init.yaml <<'EOT'
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.105.3
  bindPort: 6443
nodeRegistration:
  kubeletExtraArgs:
    node-ip: 192.168.105.3
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.34.7
controlPlaneEndpoint: 192.168.105.3:6443
networking:
  podSubnet: 10.244.0.0/16
EOT

cat > k8s/flannel.md <<'EOT'
# Flannel

Apply Flannel after `kubeadm init`:

```bash
./scripts/install-flannel.sh
```
EOT

cat > k8s/notes.md <<'EOT'
# Notes

- Kubernetes packages are pinned from pkgs.k8s.io stable v1.34
- containerd is configured with SystemdCgroup = true
- kubelet is pinned to the static `lima0` IP on each node
EOT

chmod +x scripts/*.sh

echo "Repo scaffolding written."
echo "Next:"
echo "  bash bootstrap_repo.sh"
echo "  git add . && git commit -m \"Add repo scaffolding\""
