# Lima Kubernetes HA Lab

## Overview

This project provides a reproducible local Kubernetes High Availability (HA) lab using **Lima** on macOS (Apple Silicon) with:

* 3 Control Plane nodes: `cp1`, `cp2`, `cp3`
* 2 Worker nodes: `w1`, `w2`
* Static IP networking via Netplan
* Lima `shared` network (192.168.105.0/24)

---

## Architecture

| Node | Role          | IP             |
| ---- | ------------- | -------------- |
| cp1  | Control Plane | 192.168.105.3  |
| cp2  | Control Plane | 192.168.105.4  |
| cp3  | Control Plane | 192.168.105.5  |
| w1   | Worker        | 192.168.105.11 |
| w2   | Worker        | 192.168.105.12 |

* Gateway: `192.168.105.1`
* Network: `192.168.105.0/24`

---

## Prerequisites

* macOS (Apple Silicon recommended)
* Lima installed (`brew install lima`)
* GitHub CLI (optional) (`brew install gh`)

---

## Project Structure

```
lima-k8s-ha/
├── lima/
│   ├── cp1.yaml
│   ├── cp2.yaml
│   ├── cp3.yaml
│   ├── w1.yaml
│   └── w2.yaml
├── scripts/
│   ├── create.sh
│   ├── delete.sh
│   └── hosts.sh
└── README.md
```

---

## Usage

### 1. Create all VMs

```
./scripts/create.sh
```

---

### 2. Configure /etc/hosts on all nodes

```
./scripts/hosts.sh
```

---

### 3. Verify networking

```
for n in cp1 cp2 cp3 w1 w2; do
  echo "=== $n ==="
  limactl shell "$n" ip -4 addr show lima0
  echo
done
```

Expected:

* Static IPs (no `dynamic`)
* Correct IP mapping per node

---

### 4. Delete all VMs

```
./scripts/delete.sh
```

---

## Networking Details

* Primary interface: `lima0`
* Static IP configured via Netplan
* Secondary interface `eth0` remains DHCP (ignored for cluster)

---

## Notes

* Always use `lima0` IPs for Kubernetes
* Avoid using `eth0` addresses (DHCP)
* Ensure unique MAC addresses per VM

---

## Next Steps

* Install container runtime (containerd)
* Bootstrap Kubernetes with kubeadm
* Add a Virtual IP (kube-vip) for HA control plane

---

## License

Private project for personal/lab use
# Lima K8s HA
