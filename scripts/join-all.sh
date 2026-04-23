#!/usr/bin/env bash
set -euo pipefail

CONTROL_PLANES=(cp2 cp3)
WORKERS=(w1 w2)
API_ENDPOINT="192.168.105.3:6443"

echo "Getting worker join command from cp1..."
WORKER_JOIN_CMD="$(limactl shell cp1 sudo kubeadm token create --print-join-command | tr -d '\r')"

if [[ -z "${WORKER_JOIN_CMD}" ]]; then
  echo "Failed to get worker join command"
  exit 1
fi

echo "Getting control-plane certificate key from cp1..."
CERT_KEY="$(limactl shell cp1 sudo kubeadm init phase upload-certs --upload-certs | tail -n 1 | tr -d '\r')"

if [[ -z "${CERT_KEY}" ]]; then
  echo "Failed to get certificate key"
  exit 1
fi

CONTROL_PLANE_JOIN_CMD="${WORKER_JOIN_CMD} --control-plane --certificate-key ${CERT_KEY}"

echo
echo "Worker join command:"
echo "  ${WORKER_JOIN_CMD}"
echo
echo "Control-plane join command:"
echo "  ${CONTROL_PLANE_JOIN_CMD}"
echo

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

echo "Join operations submitted."
echo "Check with:"
echo "  kubectl get nodes -o wide"
