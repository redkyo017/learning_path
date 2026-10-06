#!/usr/bin/env bash
# Reset the orderflow namespace to empty and unlabeled (no Pod Security label). Idempotent.
# Usage: bash labs/shared/reset.sh
set -euo pipefail

NS=orderflow

if command -v helm >/dev/null 2>&1 && helm status orderflow -n "${NS}" >/dev/null 2>&1; then
  echo "==> Uninstalling Helm release orderflow"
  helm uninstall orderflow -n "${NS}" --wait >/dev/null || true
fi

echo "==> Deleting namespace ${NS} (waits until gone)"
kubectl delete namespace "${NS}" --ignore-not-found --wait=true >/dev/null

echo "==> Recreating namespace ${NS} (no PSA label)"
kubectl create namespace "${NS}" >/dev/null

kubectl get namespace "${NS}" --show-labels
