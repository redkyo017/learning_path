#!/usr/bin/env bash
# Build the three orderflow images and make them visible to the current kube context's cluster.
# Usage: bash labs/shared/load-images.sh [TAG]     (default TAG: v1; works from any directory)
set -euo pipefail

TAG="${1:-v1}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES=(order-api payment-service notification-service)
NODE=desktop-control-plane

echo "==> Building orderflow/*:${TAG}"
for svc in "${SERVICES[@]}"; do
  docker build -q -t "orderflow/${svc}:${TAG}" "${HERE}/${svc}" >/dev/null
  echo "    built orderflow/${svc}:${TAG}"
done

CTX="$(kubectl config current-context 2>/dev/null || true)"
echo "==> kube context: ${CTX:-<none>}"

if [[ "${CTX}" == kind-* ]]; then
  CLUSTER="${CTX#kind-}"
  echo "==> kind: loading into cluster ${CLUSTER}"
  for svc in "${SERVICES[@]}"; do
    kind load docker-image "orderflow/${svc}:${TAG}" --name "${CLUSTER}"
  done
elif [[ "${CTX}" == "docker-desktop" ]] && [[ "$(docker inspect --type container -f '{{.State.Running}}' "${NODE}" 2>/dev/null || true)" == "true" ]]; then
  # Docker Desktop kind provisioner: nodes are containers named desktop-control-plane, desktop-worker, desktop-worker2, ...
  # Docker Desktop hides these containers from `docker ps`, but `docker inspect` by name works, so probe the names.
  for node in "${NODE}" desktop-worker desktop-worker{2..9}; do
    [[ "$(docker inspect --type container -f '{{.State.Running}}' "${node}" 2>/dev/null || true)" == "true" ]] || continue
    echo "==> Docker Desktop (kind provisioner): importing into containerd on node ${node}"
    for svc in "${SERVICES[@]}"; do
      docker save "orderflow/${svc}:${TAG}" | docker exec -i "${node}" ctr -n k8s.io images import - >/dev/null
      echo "    loaded orderflow/${svc}:${TAG}"
    done
  done
elif [[ "${CTX}" == "docker-desktop" ]]; then
  echo "==> Docker Desktop (kubeadm provisioner): cluster shares the local image store, nothing to load"
else
  echo "==> Unknown cluster type (context '${CTX:-none}'). Images are built locally only."
  echo "    Load them yourself: kind -> 'kind load docker-image IMG --name <cluster>';"
  echo "    remote cluster -> docker tag + docker push to a registry the nodes can pull from."
fi

echo "==> Done. Use image: orderflow/<service>:${TAG} with imagePullPolicy: IfNotPresent (or Never)."
