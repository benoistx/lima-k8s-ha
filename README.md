# 🚀 Lima Kubernetes HA Lab

A reproducible **local Kubernetes HA lab** for Apple Silicon Macs using **Lima**, **Ubuntu 24.04**, **static IPs**, and **kubeadm**.

This repo gives you a fast, disposable playground to practice:

- multi-control-plane Kubernetes
- worker joins
- upgrades and resets
- networking troubleshooting
- HA patterns with a future VIP/load balancer

---

## ✨ What’s in the lab

- **3 control planes**: `cp1`, `cp2`, `cp3`
- **2 workers**: `w1`, `w2`
- **Static IPs on `lima0`**
- **Ubuntu 24.04 ARM64**
- **Lima shared network**
- **containerd + kubeadm + kubelet + kubectl**

---

## 🗺️ Cluster layout

| Node | Role | IP |
| ---- | ---- | --- |
| cp1 | Control Plane | 192.168.105.3 |
| cp2 | Control Plane | 192.168.105.4 |
| cp3 | Control Plane | 192.168.105.5 |
| w1 | Worker | 192.168.105.11 |
| w2 | Worker | 192.168.105.12 |

Network details:

- Network: `192.168.105.0/24`
- Gateway: `192.168.105.1`
- Cluster interface: `lima0`
- Auxiliary DHCP interface: `eth0` (not used for Kubernetes)

---

## 🧱 Repository structure

```text
lima-k8s-ha/
├── README.md
├── .gitignore
├── docs/
│   ├── architecture.md
│   ├── bootstrap.md
│   └── troubleshooting.md
├── lima/
│   ├── cp1.yaml
│   ├── cp2.yaml
│   ├── cp3.yaml
│   ├── w1.yaml
│   └── w2.yaml
├── scripts/
│   ├── bootstrap.sh
│   ├── configure-kubectl.sh
│   ├── create.sh
│   ├── delete.sh
│   ├── hosts.sh
│   ├── init-cp1.sh
│   ├── install-flannel.sh
│   ├── prep.sh
│   ├── reset-node.sh
│   ├── show-join-info.sh
│   └── status.sh
└── k8s/
    ├── kubeadm-init.yaml
    ├── flannel.md
    └── notes.md
```

---

## 🛠️ Prerequisites

Install tools on your Mac:

```bash
brew install lima gh
```

Recommended:

- Apple Silicon Mac
- Git configured
- GitHub CLI authenticated with `gh auth login`

---

## ⚡ Quick start

### 1. Create all VMs

```bash
./scripts/create.sh
```

This script is **non-interactive** and also performs a safe cleanup before recreating nodes:

- stops existing instances if present
- deletes existing lab instances
- runs `limactl prune`
- removes only this lab’s generated logs and YAML copies from `~/.lima`
- recreates the cluster with `--tty=false`

### 2. Add host entries on all nodes

```bash
./scripts/hosts.sh
```

This script is **idempotent**:

- removes previous `cp1/cp2/cp3/w1/w2` entries from `/etc/hosts`
- writes the fresh host map
- validates the final content on each node

### 3. Bootstrap containerd + Kubernetes packages

```bash
./scripts/bootstrap.sh
```

### 4. Prepare kernel/sysctl + kubelet node IPs

```bash
./scripts/prep.sh
```

### 5. Initialize the first control plane

```bash
./scripts/init-cp1.sh
```

### 6. Configure kubectl on `cp1`

```bash
./scripts/configure-kubectl.sh
```

### 7. Install Flannel

```bash
./scripts/install-flannel.sh
```

### 8. Show join information

```bash
./scripts/show-join-info.sh
```

Then use the generated join commands to add:

- `cp2`
- `cp3`
- `w1`
- `w2`

---

## 🌐 Lima VM configuration

Each node uses:

- `vmType: vz`
- Ubuntu 24.04 ARM64 image
- `memory: "2GiB"`
- `disk: "20GiB"`
- static IP via Netplan on `lima0`
- unique MAC address for deterministic matching

Important:

- `lima0` is the Kubernetes-facing interface
- `eth0` may still receive a DHCP address and should be ignored for cluster addressing

---

## ⚠️ Notes about `vmType: vz`

This lab uses Apple’s Virtualization.framework through `vmType: vz`.

In practice, you may notice:

- VM-related processes lingering in Activity Monitor after deletion
- memory not being released immediately after stop/delete cycles

Because of that, this repo prefers a **stop → delete → prune → recreate** workflow in `scripts/create.sh`.

If your Mac gets into a bad state during heavy lab iterations:

- rerun `./scripts/create.sh`
- use `limactl prune`
- consider a host reboot if macOS keeps stale VZ processes around

---

## 📄 Example helper scripts

### `scripts/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

NODES=(cp1 cp2 cp3 w1 w2)

for n in "${NODES[@]}"; do
  limactl stop "$n" >/dev/null 2>&1 || true
done

limactl delete -f "${NODES[@]}" >/dev/null 2>&1 || true
limactl prune >/dev/null 2>&1 || true

rm -f ~/.lima/bootstrap-*.log \
      ~/.lima/setup-*.log \
      ~/.lima/k8s-setup-*.log \
      ~/.lima/cp*.yaml \
      ~/.lima/w*.yaml \
      ~/.lima/ubuntu-24.04-k8s.yaml 2>/dev/null || true

limactl start --tty=false --name=cp1 lima/cp1.yaml
limactl start --tty=false --name=cp2 lima/cp2.yaml
limactl start --tty=false --name=cp3 lima/cp3.yaml
limactl start --tty=false --name=w1 lima/w1.yaml
limactl start --tty=false --name=w2 lima/w2.yaml
```

### `scripts/delete.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

limactl delete -f cp1 cp2 cp3 w1 w2
```

### `scripts/hosts.sh`

```bash
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
```

### `scripts/bootstrap.sh`

```bash
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
echo 'Run:'
echo 'for n in cp1 cp2 cp3 w1 w2; do'
echo '  printf "===== %s =====\n" "$n"'
echo '  tail -n 30 "bootstrap-$n.log"'
echo '  echo'
echo 'done'
```

### `scripts/prep.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

for n in cp1 cp2 cp3 w1 w2; do
  (
    echo "=== $n ==="
    limactl shell "$n" sh -c '
      set -eux
      sudo swapoff -a
      sudo sed -i.bak "/ swap / s/^/#/" /etc/fstab

      cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

      sudo modprobe overlay
      sudo modprobe br_netfilter

      cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

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
echo 'Run:'
echo 'for n in cp1 cp2 cp3 w1 w2; do'
echo '  printf "===== %s =====\n" "$n"'
echo '  tail -n 30 "prep-$n.log"'
echo '  echo'
echo 'done'
```

### `scripts/init-cp1.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sudo kubeadm init \
  --control-plane-endpoint 192.168.105.3:6443 \
  --apiserver-advertise-address 192.168.105.3 \
  --pod-network-cidr 10.244.0.0/16 \
  --upload-certs
```

### `scripts/status.sh`

```bash
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
```

---

## ✅ Validation checklist

Before `kubeadm init`, verify:

- all 5 VMs are running
- `lima0` has the expected static IP on each node
- `containerd` is active everywhere
- `kubeadm`, `kubelet`, and `kubectl` are installed everywhere
- swap is off
- `br_netfilter` and `overlay` are loaded
- kubelet is pinned to the `lima0` IP
- `/etc/hosts` entries are correct on every node

Useful command:

```bash
./scripts/status.sh
```

---

## ☸️ Kubernetes bootstrap flow

1. Run `./scripts/create.sh`
2. Run `./scripts/hosts.sh`
3. Run `./scripts/bootstrap.sh`
4. Run `./scripts/prep.sh`
5. Run `./scripts/init-cp1.sh`
6. Run `./scripts/configure-kubectl.sh`
7. Run `./scripts/install-flannel.sh`
8. Run `./scripts/show-join-info.sh`
9. Join `cp2` and `cp3` as control planes
10. Join `w1` and `w2` as workers

Example after init on `cp1`:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes -o wide
```

---

## 🔥 Nice next upgrades

Once the base cluster works, this repo can grow into a seriously good HA lab:

- add **kube-vip** for a real HA control-plane endpoint
- add **Flannel**, **Calico**, or **Cilium**
- add a `join.sh` helper
- add an `upgrade.sh` workflow
- export kubeconfig back to the Mac host
- add GitHub Actions for linting shell/YAML files

---

## 🧹 Suggested `.gitignore`

```gitignore
.DS_Store
*.log
*.swp
*.tmp
```

---

## 🧠 Notes

- This repo is optimized for **Lima on Apple Silicon**
- Static IPs are configured on `lima0`, not `eth0`
- The first control-plane endpoint currently points to `cp1`
- For true control-plane endpoint HA, add a VIP later
- `vmType: vz` is fast and convenient, but repeated delete/recreate cycles may leave stale-looking memory/process traces on macOS

---

## 🏁 Goal

A fast, disposable, realistic Kubernetes lab you can:

- rebuild anytime
- break without fear
- practice on repeatedly
- version in GitHub like real infrastructure

Enjoy breaking things — on purpose 😄
