# 🚀 Lima Kubernetes HA Lab

A reproducible **local Kubernetes HA lab** for deploying a **5-node Kubernetes cluster on macOS ARM (Apple Silicon)** using **Lima**, **Ubuntu 24.04**, **static IPs**, and **kubeadm**.

> Tested on **macOS (Apple Silicon)** using Lima with the **VZ (Virtualization.framework) backend**.

This repo gives you a fast, disposable playground to practice:

- multi-control-plane Kubernetes
- worker joins
- upgrades and resets
- networking troubleshooting
- HA patterns with a future VIP/load balancer

---

## ✨ Current status

This lab is now validated with a working **5-node cluster**:

- `lima-cp1` ✅ Ready
- `lima-cp2` ✅ Ready
- `lima-cp3` ✅ Ready
- `lima-w1` ✅ Ready
- `lima-w2` ✅ Ready

Kubernetes version:

- **v1.34.7**

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
│   ├── export-kubeconfig.sh
│   ├── hosts.sh
│   ├── init-cp1.sh
│   ├── install-flannel.sh
│   ├── join-all.sh
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
brew install lima gh kubectl
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

### 8. Join all remaining nodes automatically

```bash
./scripts/join-all.sh
```

### 9. Export kubeconfig to your Mac host

```bash
./scripts/export-kubeconfig.sh
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes -o wide
```

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

### `scripts/install-flannel.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

limactl shell cp1 sh -c '
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A
'
```

### `scripts/join-all.sh`

```bash
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
```

### `scripts/export-kubeconfig.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-kubeconfig}"
API_SERVER="192.168.105.3"

limactl shell cp1 sudo cat /etc/kubernetes/admin.conf > "$OUTPUT_FILE"
sed -i '' "s/127.0.0.1/${API_SERVER}/" "$OUTPUT_FILE"

echo "Use with:"
echo "  export KUBECONFIG=$PWD/${OUTPUT_FILE}"
echo "  kubectl get nodes -o wide"
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

After full deployment, verify:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
```

Expected result: all 5 nodes in `Ready`.

---

## ☸️ Kubernetes bootstrap flow

1. Run `./scripts/create.sh`
2. Run `./scripts/hosts.sh`
3. Run `./scripts/bootstrap.sh`
4. Run `./scripts/prep.sh`
5. Run `./scripts/init-cp1.sh`
6. Run `./scripts/configure-kubectl.sh`
7. Run `./scripts/install-flannel.sh`
8. Run `./scripts/join-all.sh`
9. Run `./scripts/export-kubeconfig.sh`
10. Run `kubectl get nodes -o wide`

Example from the host after export:

```bash
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
```

---

## 🔥 Nice next upgrades

Once the base cluster works, this repo can grow into a seriously good HA lab:

- add **kube-vip** for a real HA control-plane endpoint
- add **Flannel**, **Calico**, or **Cilium**
- add an `upgrade.sh` workflow
- add HA endpoint failover tests
- add GitHub Actions for linting shell/YAML files

---

## 🧹 Suggested `.gitignore`

```gitignore
.DS_Store
*.log
*.swp
*.tmp
kubeconfig
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

