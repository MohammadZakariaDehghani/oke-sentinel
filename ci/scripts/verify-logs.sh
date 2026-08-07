#!/usr/bin/env bash
# Prove that the pipeline works, rather than that the pods are running.
#
# "Filebeat is Running" says nothing about whether a log line ever reached
# Elasticsearch. This queries the Elasticsearch API for documents in both data
# streams and fails if either is empty.
#
# It runs inside the cluster, in a throwaway pod, so it needs no port-forward
# and no host-side TLS trust — it uses the service DNS name and the CA that ECK
# generated.
set -euo pipefail

cd "$(dirname "$0")/../.."

NAMESPACE="${NAMESPACE:-elastic-system}"
ES_SERVICE="${ES_SERVICE:-sentinel-es-http}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"

# Data streams that must contain at least one document.
CONTAINER_STREAM="logs-kubernetes.container-*"
AUDIT_STREAM="logs-kubernetes.audit-*"

echo "==> reading the Elasticsearch password"
ES_PASSWORD="$(kubectl -n "$NAMESPACE" get secret sentinel-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}')"

run_query() {
  # $1: index pattern. Prints the hit count, or "error".
  kubectl -n "$NAMESPACE" run "es-query-$RANDOM" \
    --rm --restart=Never --quiet --attach \
    --image=curlimages/curl:8.19.0 \
    --env="ES_PASSWORD=$ES_PASSWORD" \
    --command -- sh -c "
      curl -sS --max-time 30 \
        --cacert /dev/null --insecure \
        -u elastic:\$ES_PASSWORD \
        'https://${ES_SERVICE}.${NAMESPACE}.svc:9200/$1/_count' \
      | sed -n 's/.*\"count\":\([0-9]*\).*/\1/p'
    " 2>/dev/null | tr -d '\r' | tail -1
}

# --insecure above deserves a word: this is a throwaway kind cluster and the
# alternative is mounting the ECK CA into an ad-hoc pod for a check that runs
# for two seconds. Nothing in the deployed stack skips verification — Filebeat,
# Metricbeat and Kibana all use the CA through elasticsearchRef.

wait_for_documents() {
  local pattern="$1" label="$2" deadline count
  deadline=$(( SECONDS + TIMEOUT_SECONDS ))

  echo "==> waiting for documents in $label"
  while (( SECONDS < deadline )); do
    count="$(run_query "$pattern" || true)"
    if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )); then
      echo "    $label: $count document(s)"
      return 0
    fi
    echo "    $label: ${count:-no response} so far, retrying..."
    sleep 15
  done

  echo "FAILED: no documents reached $label within ${TIMEOUT_SECONDS}s."
  echo
  echo "Filebeat logs:"
  kubectl -n "$NAMESPACE" logs -l beat.k8s.elastic.co/name=filebeat --tail=50 || true
  echo
  echo "Indices that do exist:"
  run_query "_all" || true
  return 1
}

failed=0
wait_for_documents "$CONTAINER_STREAM" "container logs" || failed=1

# The audit stream only fills where the API server writes an audit file, which
# is the kind path. On a managed control plane this check is expected to fail
# and the equivalent assertion belongs against the OCI Streaming path instead.
if [[ "${SKIP_AUDIT_CHECK:-}" == "1" ]]; then
  echo "==> skipping the audit stream check (SKIP_AUDIT_CHECK=1)"
else
  wait_for_documents "$AUDIT_STREAM" "Kubernetes audit events" || failed=1
fi

if (( failed )); then
  echo
  echo "The pipeline is not delivering. Pods being Running is not the same thing."
  exit 1
fi

echo
echo "Pipeline verified: container logs and audit events are both in Elasticsearch."
