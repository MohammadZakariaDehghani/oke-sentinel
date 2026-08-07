# Kibana saved objects

`dashboard.ndjson` contains the **OKE Sentinel — cluster security posture**
dashboard: one data view, seven visualisations, and the dashboard that arranges
them.

## Panels

| Panel | Related detection |
|---|---|
| Audit events (total) | — collection health; a sudden drop means ingestion broke |
| Busiest identities | — baseline; a new identity here is worth explaining |
| Audit events over time by verb | — writes outside a deploy window |
| Authorisation failures by identity | `rbac-denied-burst` |
| Secret reads by identity | `secret-enumeration` |
| Interactive sessions into containers | `exec-into-pod` |
| RBAC changes | `cluster-admin-binding-created` |

## Importing

```bash
curl -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -u "elastic:$ELASTIC_PASSWORD" \
  --form file=@security/kibana/dashboard.ndjson
```

The CI integration job does exactly this against the kind cluster and asserts
`"success": true`, so a change that breaks the file is caught on the pull
request rather than the next time someone needs the dashboard.

## Editing

Edit in Kibana, then export and commit — do not hand-edit the NDJSON:

```bash
curl -X POST "$KIBANA_URL/api/saved_objects/_export" \
  -H "kbn-xsrf: true" -H 'Content-Type: application/json' \
  -u "elastic:$ELASTIC_PASSWORD" \
  -d '{"objects":[{"type":"dashboard","id":"1c7d5ae0-sentinel-security-posture"}],
       "includeReferencesDeep":true}' \
  -o security/kibana/dashboard.ndjson
```

Object IDs are fixed rather than randomly generated, so re-importing updates
the existing dashboard instead of creating a second copy each time.

## A note on provenance

This file was generated programmatically rather than exported from a live
Kibana, because the environment it was written in had no cluster to export
from. Its structure is validated on every run of the integration job — the
import above either succeeds or the job fails. If Kibana's saved-object format
shifts in a future major version, that job is where you will find out.
