#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-demo-app}"
NAMESPACE="${NAMESPACE:-default}"
PORT="${PORT:-8080}"

# candidate paths (first that returns 200 wins)
PATHS=("/healthz" "/health" "/")

echo "Starting port-forward for ${APP_NAME}..."
kubectl -n "${NAMESPACE}" port-forward "deploy/${APP_NAME}" "${PORT}:${PORT}" >/tmp/pf-"${APP_NAME}".log 2>&1 &
PF_PID=$!
trap "kill ${PF_PID} >/dev/null 2>&1 || true" EXIT
sleep 2

ok=false
for p in "${PATHS[@]}"; do
  echo "Trying: http://127.0.0.1:${PORT}${p}"
  code=$(curl -s -o /tmp/smoke.body -w "%{http_code}" "http://127.0.0.1:${PORT}${p}" || true)
  if [[ "$code" == "200" ]]; then
    echo "✅ Smoke OK on ${p}"
    ok=true
    break
  fi
done

if [[ "$ok" != "true" ]]; then
  echo "❌ Smoke failed. Last response:"
  tail -n 50 /tmp/smoke.body || true
  exit 1
fi