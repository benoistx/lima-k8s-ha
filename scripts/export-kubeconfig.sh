#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${1:-kubeconfig}"
API_SERVER="192.168.105.3"

echo "Exporting kubeconfig from cp1 to ${OUTPUT_FILE}..."
limactl shell cp1 sudo cat /etc/kubernetes/admin.conf > "$OUTPUT_FILE"

echo "Rewriting API server endpoint to ${API_SERVER}..."
sed -i '' "s/127.0.0.1/${API_SERVER}/" "$OUTPUT_FILE"

echo "Done"
echo "Use with:"
echo "  export KUBECONFIG=$PWD/${OUTPUT_FILE}"
echo "  kubectl get nodes"
