#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-demo-app}"
NAMESPACE="${NAMESPACE:-default}"

echo ""
echo "========== DEBUG DUMP =========="
echo "Context: $(kubectl config current-context)"
echo "Namespace: ${NAMESPACE}"
echo "App: ${APP_NAME}"
echo ""

echo "---- pods ----"
kubectl get pods -n "${NAMESPACE}" -o wide || true

echo ""
echo "---- events (last 40) ----"
kubectl get events -n "${NAMESPACE}" --sort-by=.metadata.creationTimestamp | tail -n 40 || true

echo ""
echo "---- describe pods ----"
kubectl describe pod -n "${NAMESPACE}" -l app="${APP_NAME}" | tail -n 200 || true

echo ""
echo "---- logs (last 200 lines) ----"
kubectl logs -n "${NAMESPACE}" -l app="${APP_NAME}" --tail=200 || true

echo "========== END DEBUG DUMP =========="