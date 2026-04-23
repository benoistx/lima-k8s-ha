# 🚀 Lima Kubernetes HA Lab

Welcome to your **local Kubernetes playground on steroids** — fully reproducible, multi-node, and ready for real HA experiments.

Spin up a 5-node cluster on your Mac in minutes, break it, fix it, and learn *way* faster than with cloud setups 💥

---

## 🧠 What You’re Building

A **realistic Kubernetes HA lab** with:

* 🧩 3 Control Plane nodes (`cp1`, `cp2`, `cp3`)
* ⚙️ 2 Worker nodes (`w1`, `w2`)
* 🌐 Static networking (no surprises, no DHCP chaos)
* 🖥️ Running locally with Lima (Apple Silicon optimized)

---

## 🗺️ Cluster Map

| Node | Role             | IP             |
| ---- | ---------------- | -------------- |
| cp1  | 🧠 Control Plane | 192.168.105.3  |
| cp2  | 🧠 Control Plane | 192.168.105.4  |
| cp3  | 🧠 Control Plane | 192.168.105.5  |
| w1   | ⚙️ Worker        | 192.168.105.11 |
| w2   | ⚙️ Worker        | 192.168.105.12 |

* 🌐 Network: `192.168.105.0/24`
* 🚪 Gateway: `192.168.105.1`

---

## ⚡ Why This Setup Is Awesome

* 🔁 Fully reproducible (destroy & rebuild anytime)
* 🧪 Perfect for CKA / CKAD / CKS practice
* 🔥 Real HA control plane (not fake single-node labs)
* 🧱 Infrastructure-as-code mindset

---

## 🧰 Prerequisites

* macOS (Apple Silicon recommended 🍏)
* Lima installed:

```bash
brew install lima
```

* GitHub CLI (optional):

```bash
brew install gh
```

---

## 📁 Project Structure

```
lima-k8s-ha/
├── lima/        # VM definitions
├── scripts/     # helper scripts
└── README.md
```

---

## 🚀 Quick Start

### 1. Create all VMs

```bash
./scripts/create.sh
```

☕ Grab a coffee — Lima will boot your mini data center.

---

### 2. Configure /etc/hosts

```bash
./scripts/hosts.sh
```

Now your nodes can talk like civilized machines:

```bash
ping cp2
ping w1
```

---

### 3. Verify networking

```bash
for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="
  limactl shell "$n" ip -4 addr show lima0
  echo
done
```

✅ Expect:

* Static IPs
* No `dynamic`

---

### 4. Destroy everything (and feel powerful)

```bash
./scripts/delete.sh
```

💥 Gone. Clean slate.

---

## 🌐 Networking Deep Dive

* `lima0` → your cluster network (STATIC ✅)
* `eth0` → background DHCP (ignore ❌)

👉 Kubernetes should ONLY use `lima0`

---

## 🧪 Things You Can Try

* Kill a control plane node 🔪
* Reboot everything 🔄
* Break networking 😈
* Practice upgrades ⬆️
* Test HA failover ⚖️

This lab is meant to be **abused safely**.

---

## 🔜 Next Level

* Install containerd
* Bootstrap cluster with kubeadm
* Add **kube-vip** for real HA endpoint
* Deploy CNI (Calico / Cilium)

---

## 🧩 Pro Tip

If something breaks:

```bash
limactl delete -f cp1 cp2 cp3 w1 w2
./scripts/create.sh
```

🔥 Fast recovery > slow debugging

---

## 🏁 Goal

Turn this into your **go-to Kubernetes lab**:

* repeatable
* fast
* realistic

---

Enjoy breaking things 😄

