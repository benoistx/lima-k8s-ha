# 🚀 Lima Kubernetes HA Lab

A reproducible **local Kubernetes HA lab** for Apple Silicon Macs using **Lima**, **Ubuntu 24.04**, **static IPs**, and **kubeadm**.

This repo gives you a fast, disposable playground to practice:

* multi-control-plane Kubernetes
* worker joins
* upgrades and resets
* networking troubleshooting
* HA patterns with a future VIP/load balancer

---

## ✨ What’s in the lab

* **3 control planes**: `cp1`, `cp2`, `cp3`
* **2 workers**: `w1`, `w2`
* **Static IPs on `lima0`**
* **Ubuntu 24.04 ARM64**
* **Lima shared network**
* **containerd + kubeadm + kubelet + kubectl**

---

## 🗺️ Cluster layout

| Node | Role          | IP             |
| ---- | ------------- | -------------- |
| cp1  | Control Plane | 192.168.105.3  |
| cp2  | Control Plane | 192.168.105.4  |
| cp3  | Control Plane | 192.168.105.5  |
| w1   | Worker        | 192.168.105.11 |
| w2   | Worker        | 192.168.105.12 |

Network details:

* Network: `192.168.105.0/24`
* Gateway: `192.168.105.1`
* Cluster interface: `lima0`
* Auxiliary DHCP interface: `eth0` (not used for Kubernetes)

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
│   ├── create.sh
│   ├── delete.sh
│   ├── hosts.sh
│   ├── bootstrap.sh
│   ├── prep.sh
│   ├── init-cp1.sh
│   ├── reset-node.sh
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

* Apple Silicon Mac
* Git configured
* GitHub CLI authenticated with `gh auth login`

---

## ⚡ Quick start

### 1. Create all VMs

```bash
./scripts/create.sh
```

### 2. Add host entries on all nodes

```bash
./scripts/hosts.sh
```

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

### 6. Join the remaining nodes

After `kubeadm init`, use the generated join commands to add:

* `cp2`
* `cp3`
* `w1`
* `w2`

---

## 🌐 Lima VM configuration

Each node uses:

* `vmType: vz`
* Ubuntu 24.04 ARM64 image
* `memory: "2GiB"`
* `disk: "20GiB"`
* static IP via Netplan on `lima0`
* unique MAC address for deterministic matching

Important:

* `lima0` is the Kubernetes-facing interface
* `eth0` may still receive a DHCP address and should be ignored for cluster addressing

---

## 📄 Example helper scripts

### `scripts/create.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

limactl delete -f cp1 cp2 cp3 w1 w2 || true
limactl start --name=cp1 lima/cp1.yaml
limactl start --name=cp2 lima/cp2.yaml
limactl start --name=cp3 lima/cp3.yaml
limactl start --name=w1 lima/w1.yaml
limactl start --name=w2 lima/w2.yaml
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
  echo "$HOSTS_CONTENT" | limactl shell "$n" sudo tee -a /etc/hosts >/dev/null
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

      systemctl is-active containerd
      kubeadm version -o short
    '
  ) >"bootstrap-$n.log" 2>&1 &
done

wait
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
    hostname
    ip -4 addr show lima0 | sed -n "2p"
    ip route | grep default || true
    systemctl is-active containerd || true
  '
  echo
done
```

---

## ✅ Validation checklist

Before `kubeadm init`, verify:

* all 5 VMs are running
* `lima0` has the expected static IP on each node
* `containerd` is active everywhere
* `kubeadm`, `kubelet`, and `kubectl` are installed everywhere
* swap is off
* `br_netfilter` and `overlay` are loaded
* kubelet is pinned to the `lima0` IP

Useful command:

```bash
./scripts/status.sh
```

---

## ☸️ Kubernetes bootstrap flow

1. Run `./scripts/bootstrap.sh`
2. Run `./scripts/prep.sh`
3. Run `./scripts/init-cp1.sh`
4. Save the join commands from `kubeadm init`
5. Join `cp2` and `cp3` as control planes
6. Join `w1` and `w2` as workers
7. Install a CNI plugin such as Flannel

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

* add **kube-vip** for a real HA control-plane endpoint
* add **Flannel**, **Calico**, or **Cilium**
* add a `join.sh` helper
* add an `upgrade.sh` workflow
* export kubeconfig back to the Mac host
* add GitHub Actions for linting shell/YAML files

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

* This repo is optimized for **Lima on Apple Silicon**
* Static IPs are configured on `lima0`, not `eth0`
* The first control-plane endpoint currently points to `cp1`
* For true control-plane endpoint HA, add a VIP later

---

## 🏁 Goal

A fast, disposable, realistic Kubernetes lab you can:

* rebuild anytime
* break without fear
* practice on repeatedly
* version in GitHub like real infrastructure

Enjoy breaking things — on purpose 😄
