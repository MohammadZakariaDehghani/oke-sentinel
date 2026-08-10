#!/usr/bin/env bash
# Install the ECK operator and the local Elastic Stack onto the current
# kubectl context.
#
# Intended for a kind cluster created by `make kind-up`. It refuses to run
# against anything else, because the local overlay has no resource headroom
# assumptions that hold on a real cluster and this script is not the way to
# deploy to OKE — that is `kubectl apply -k kubernetes/overlays/dev`.
set -euo pipefail

cd "$(dirname "$0")/../.."

# shellcheck source=../../kubernetes/versions.env
source kubernetes/versions.env

CONTEXT="$(kubectl config current-context)"
EXPECTED_CONTEXT="${EXPECTED_CONTEXT:-kind-oke-sentinel}"

if [[ "$CONTEXT" != "$EXPECTED_CONTEXT" ]]; then
  echo "Refusing to run: kubectl context is '$CONTEXT', expected '$EXPECTED_CONTEXT'."
  echo "Run 'make kind-up' first, or set EXPECTED_CONTEXT if you know what you are doing."
  exit 1
fi

echo "==> installing ECK ${ECK_VERSION} custom resource definitions"
# `create`, not `apply`: the ECK CRDs exceed the annotation size limit that
# `kubectl apply` uses to store its last-applied configuration, and apply fails
# on a fresh cluster with a metadata.annotations too-long error.
kubectl create -f "${ECK_CRDS_URL}" 2>/dev/null ||
  kubectl replace -f "${ECK_CRDS_URL}"

echo "==> installing the ECK operator"
kubectl apply -f "${ECK_OPERATOR_URL}"

echo "==> waiting for the operator to become ready"
kubectl -n elastic-system rollout status statefulset/elastic-operator --timeout=5m

echo "==> applying the local overlay"
kubectl apply -k kubernetes/overlays/local

echo "==> waiting for Elasticsearch to report a healthy state"
# ECK sets .status.health on the Elasticsearch resource. A single-node cluster
# settles at "yellow", never "green", because the replicas it is configured for
# have nowhere to go. Waiting for green here would hang until the timeout.
for _ in $(seq 1 60); do
  health="$(kubectl -n elastic-system get elasticsearch sentinel \
    -o jsonpath='{.status.health}' 2>/dev/null || true)"
  if [[ "$health" == "green" || "$health" == "yellow" ]]; then
    echo "    Elasticsearch health: $health"
    break
  fi
  echo "    health='${health:-unknown}', waiting..."
  sleep 10
done

if [[ "${health:-}" != "green" && "${health:-}" != "yellow" ]]; then
  echo "Elasticsearch did not become healthy in time. Recent operator logs:"
  kubectl -n elastic-system logs statefulset/elastic-operator --tail=50 || true
  kubectl -n elastic-system get pods
  exit 1
fi

echo "==> waiting for Kibana"
kubectl -n elastic-system wait --for=condition=Available deployment \
  -l kibana.k8s.elastic.co/name=sentinel --timeout=10m || {
  echo "Kibana did not become available; continuing, since the log pipeline does not depend on it."
}

echo "==> waiting for the bootstrap job to apply ILM policies and index templates"
kubectl -n elastic-system wait --for=condition=complete job/sentinel-bootstrap --timeout=10m || {
  echo "Bootstrap job did not complete. Logs:"
  kubectl -n elastic-system logs job/sentinel-bootstrap --tail=100 || true
  exit 1
}

cat <<'EOF'

Stack is up.

  Elasticsearch password:
    kubectl -n elastic-system get secret sentinel-es-elastic-user \
      -o go-template='{{.data.elastic | base64decode}}{{"\n"}}'

  Port-forward Elasticsearch:
    kubectl -n elastic-system port-forward service/sentinel-es-http 9200

  Port-forward Kibana:
    kubectl -n elastic-system port-forward service/sentinel-kb-http 5601

  Check that logs are arriving:
    ./ci/scripts/verify-logs.sh
EOF
