# Running and testing

Three ways to exercise this project, in increasing order of cost:

| Layer | Needs | Time | What it proves |
|---|---|---|---|
| [Static checks](#1-static-checks) | Nothing but the CLI tools | seconds | The code is well-formed, typed, lint-clean, secret-free, and the detection rules are internally consistent |
| [Local cluster](#2-local-cluster-kind) | Docker, ~6 GB free RAM | ~10 min | The pipeline actually works: logs and audit events reach Elasticsearch and the detection rules fire on them |
| [Real OCI](#3-real-oci) | An OCI tenancy, real money | ~30 min | The Terraform applies and OKE comes up |

Most of the value is in the first two. **The local cluster path is the one that
proves the thing works**, and it costs nothing.

> **Status.** Sections 4–7 of this project (the sample workload, the governance
> CLI, and the GitHub Actions and GitLab pipelines) are not written yet. This
> document covers what is in the repository today and marks the gaps inline.
> Commands listed here were run in the environment described under
> [What was actually verified](#what-was-actually-verified).

## Prerequisites

Not all of these are needed for all three layers. `make tools-check` prints
what you have.

| Tool | Needed for | Verified against |
|---|---|---|
| Python 3.11+ | everything | 3.11.15 |
| [uv](https://docs.astral.sh/uv/) | installing the Python projects | 0.8.17 |
| ruff | linting | 0.15.8 |
| mypy | type checking | 1.19.1 |
| pytest | tests | 9.x |
| terraform | the Terraform layer | 1.15.8 |
| checkov | Terraform security scanning | 3.3.9 |
| tflint | Terraform linting | any recent |
| detect-secrets | secret scanning | 1.5.0 |
| kubectl | rendering manifests, local cluster | 1.36.3 (kustomize 5.8.1) |
| kind | local cluster | 0.24+ |
| Docker | local cluster | any recent |

```bash
make tools-check     # what is installed
make setup           # install the Python projects and the git hooks
```

`make setup` also installs the pre-commit hooks, so the static checks run
before each commit without you remembering to.

---

## 1. Static checks

No cloud account, no cluster, no Docker. This is what CI runs on every pull
request and what you should run before pushing.

```bash
make lint     # ruff, mypy, terraform fmt, tflint, checkov, kustomize render
make test     # pytest, including the detection rule tests
```

**Targets skip loudly when a tool is missing.** If you do not have Terraform
installed, `make lint` prints `SKIPPED: terraform is not installed` and carries
on, so someone working only on the Python side is not blocked. CI installs
every tool, so nothing is skipped there. Watch for those lines — a green
`make lint` that skipped four checks is not the same as a green one that ran
them, and `make tools-check` tells you which you got.

Or individually:

```bash
make py-lint          # ruff check + ruff format --check
make py-type          # mypy
make py-test          # pytest for each Python project
make detections-test  # structural tests for the six detection rules
make tf-fmt-check     # terraform fmt -check -recursive
make tf-validate      # terraform init -backend=false + validate, per stack
make tf-lint          # tflint
make tf-checkov       # checkov, one invocation per stack
make k8s-render       # render all three Kustomize overlays
make secrets-scan     # detect-secrets, failing on anything unreviewed
```

### What each one actually catches

**`make detections-test`** is the most interesting of these, because it catches
a failure mode that is otherwise invisible. Querying an Elasticsearch field
that the index does not map returns *zero hits rather than an error* — so a
detection rule with a typo in a field name looks exactly like a rule that is
working correctly and finding nothing. It stays that way until the day you need
it. `test_every_queried_field_is_mapped` reads the mapping out of the deployed
manifest (`kubernetes/base/ilm/policies.yaml`, not a copy) and checks every
field every rule queries. It has already caught one real instance of this.

**`make tf-checkov`** runs checkov once per stack rather than passing it
several directories, deliberately. Given `-d a -d b`, checkov scans `a` and
then reports `a`'s results again cumulatively — findings in `b` never appear.
That silently hid two real findings in the bootstrap stack until it was split.

**`make secrets-scan`** requires every finding in `.secrets.baseline` to carry
an explicit reviewed marker. A newly introduced finding arrives unmarked and
fails the build. If it flags something benign:

```bash
detect-secrets audit .secrets.baseline   # interactive; mark it, then commit
```

**`make k8s-render`** is cheap and catches a surprising amount — a bad patch
path, a resource referenced from outside its overlay directory, a namespace
transformer colliding with the Namespace objects themselves.

### Rendering manifests to read them

```bash
kubectl kustomize kubernetes/overlays/local   # single node, no OCI
kubectl kustomize kubernetes/overlays/dev     # OKE, two worker nodes
kubectl kustomize kubernetes/overlays/prod    # OKE, HA
```

Diffing two overlays is the quickest way to see what an environment actually
changes:

```bash
diff <(kubectl kustomize kubernetes/overlays/dev) \
     <(kubectl kustomize kubernetes/overlays/prod)
```

---

## 2. Local cluster (kind)

This is the path worth running. It stands up a real Kubernetes control plane
that *we* own, which means the audit policy can be installed and the whole
detection pipeline can be tested end to end — on a laptop, with no OCI account.

### Sizing

Elasticsearch is the constraint, not Kubernetes. The local overlay runs one
all-roles Elasticsearch node with a 1 GB heap in a 2 GB container, plus Kibana
at 1 GB and two Beats at 300 MB each.

**Give Docker at least 6 GB of memory.** With less, Elasticsearch is
OOM-killed partway through starting and the failure looks like an unrelated
timeout. On Docker Desktop this is Settings → Resources.

### Bring it up

```bash
make kind-up        # create the cluster with the audit policy wired in
make local-stack    # install ECK, Elasticsearch, Kibana, Filebeat, Metricbeat
make local-verify   # assert that logs have actually arrived
```

`make local-verify` is the one that matters. It queries the Elasticsearch API
for documents in both `logs-kubernetes.container-*` and
`logs-kubernetes.audit-*` and fails if either is empty. Pods being `Running`
tells you nothing about whether a log line ever made it.

### Poke at it

```bash
# The generated superuser password
kubectl -n elastic-system get secret sentinel-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}{{"\n"}}'

# Elasticsearch on https://localhost:9200 (self-signed cert, so -k)
kubectl -n elastic-system port-forward service/sentinel-es-http 9200

# Kibana on https://localhost:5601, log in as elastic
kubectl -n elastic-system port-forward service/sentinel-kb-http 5601
```

### Run the detection rules against real data

With Elasticsearch port-forwarded:

```bash
export ES_URL=https://localhost:9200
export ES_PASSWORD=$(kubectl -n elastic-system get secret sentinel-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}')
export ES_INSECURE=1     # ECK's self-signed CA

make detections-test-integration
```

This indexes each rule's fixtures into a throwaway index built from the
*deployed* audit mapping, runs the rule's own query, and asserts it matches
every `match` fixture and none of the `no_match` ones. A rule that cannot find
its own positive fixtures will not find the real thing either.

### Generate something for the rules to catch

The detections read the audit log, so you can trigger them by hand:

```bash
# exec-into-pod
kubectl -n elastic-system exec -it sentinel-es-all-0 -- /bin/sh -c 'echo hello'

# privileged-pod-created
kubectl -n default run escape --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"hostPID":true}}' -- sleep 60

# rbac-denied-burst — 12 denials from one identity
kubectl -n default create serviceaccount probe
for i in $(seq 1 12); do
  kubectl -n default get secrets --as=system:serviceaccount:default:probe || true
done
```

Then look for them in Elasticsearch:

```bash
curl -sk -u "elastic:$ES_PASSWORD" \
  "https://localhost:9200/logs-kubernetes.audit-*/_search?size=5&q=objectRef.subresource:exec" \
  | python3 -m json.tool
```

### Import the dashboard

```bash
KIBANA_URL=https://localhost:5601
curl -sk -X POST "$KIBANA_URL/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" -u "elastic:$ES_PASSWORD" \
  --form file=@security/kibana/dashboard.ndjson
```

Expect `"success": true`. See [`security/kibana/README.md`](../security/kibana/README.md).

### Tear down

```bash
make kind-down
```

---

## 3. Real OCI

This costs money. Read the cost note in the README first.

Nothing in this repository has been applied to a live tenancy — see
[What was actually verified](#what-was-actually-verified). Treat the first
apply as a first apply.

### Authenticate

The provider reads `~/.oci/config` by profile, so no key material or
fingerprint is ever written into this repository:

```bash
oci session authenticate     # or set up an API key profile
```

### Bootstrap, once

Creates the state bucket and the defined tag namespace that the environment
stacks depend on. Its own state is local — the usual chicken and egg.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
terraform output s3_compatible_endpoint        # needed below
```

Create a Customer Secret Key for the state backend (in the console is
recommended — the secret half is shown once) and export it:

```bash
export AWS_ACCESS_KEY_ID="<access key>"
export AWS_SECRET_ACCESS_KEY="<secret key>"
```

### An environment

```bash
cd terraform/environments/dev
cp backend.hcl.example backend.hcl              # then edit
cp terraform.tfvars.example terraform.tfvars    # then edit
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Read the plan. Every OCID in the example tfvars is a placeholder, so a plan
that looks sensible means you replaced them.

### Deploy the stack onto OKE

```bash
eval "$(terraform output -raw kubeconfig_command)"

# Install the ECK operator (versions come from kubernetes/versions.env)
source kubernetes/versions.env
kubectl create -f "$ECK_CRDS_URL"
kubectl apply -f "$ECK_OPERATOR_URL"

# The External Secrets Operator, via Helm
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace --version "$EXTERNAL_SECRETS_VERSION"

# Edit the vault OCID and region in the overlay first — they are placeholders
$EDITOR kubernetes/overlays/dev/patch-secretstore.yaml

kubectl apply -k kubernetes/overlays/dev
```

### Tear down

```bash
kubectl delete -k kubernetes/overlays/dev
terraform destroy
```

`terraform destroy` will not remove the prod compartment — `enable_delete` is
`false` there on purpose. The Elasticsearch data volumes also survive, because
the storage class uses `reclaimPolicy: Retain`. Both are deliberate; delete
them by hand once you are sure.

---

## Troubleshooting

**`terraform init` fails with a registry error.** The provider is downloaded
from `registry.terraform.io`. Behind a restrictive proxy this fails; there is
no offline fallback short of a provider mirror.

**`kind create cluster` fails unmarshalling the kubeadm config.** The audit
config in `ci/kind-cluster.yaml` uses kubeadm's v1beta4 API, where `extraArgs`
is a list of `{name, value}` pairs. Kubernetes 1.31 changed this from a plain
map. If you pin an older node image, that block needs the map form — the file
says so where it matters.

**Elasticsearch pod is `Pending` forever.** Almost always memory. Check
`kubectl -n elastic-system describe pod` for an unschedulable message, and give
Docker more RAM.

**Elasticsearch starts and then dies with an mmap error.** `vm.max_map_count`
on the host is too low. The local overlay sets `node.store.allow_mmap: false`
to avoid needing to change a host sysctl, so if you see this you are probably
running the dev or prod overlay on kind.

**The bootstrap job hangs.** It waits for cluster health `yellow`, not `green`
— a single-node cluster can never be green, because the replicas it is
configured for have nowhere to go. If it is hanging on something else, read
`kubectl -n elastic-system logs job/sentinel-bootstrap`.

**`make local-verify` reports zero documents in the audit stream.** The API
server is not writing an audit file. That is expected on a managed control
plane and a bug on kind — check that
`/var/log/kubernetes/audit/audit.log` exists inside the control-plane
container.

**A detection rule finds nothing.** Run `make detections-test` first. If the
field-mapping test passes and the rule still finds nothing against real data,
the events are probably not shaped the way the fixtures assume — compare a real
document against a fixture.

---

## What was actually verified

Being precise about this, because "it works" should mean something.

Everything below was run in a Linux container with Python 3.11.15,
Terraform 1.15.8, kubectl 1.36.3 (kustomize 5.8.1), checkov 3.3.9,
detect-secrets 1.5.0 and ruff 0.15.8:

| Check | Result |
|---|---|
| `terraform fmt -check -recursive` | Clean across 7 directories |
| checkov, per stack | dev 35 passed / 0 failed, prod 35 / 0, bootstrap 4 / 0 |
| Cross-file Terraform reference analysis | 0 errors, 0 warnings |
| `kubectl kustomize` on all three overlays | Render; output parsed back and asserted |
| Detection rule structural tests | 70 passed |
| ILM policies and index templates | All 6 JSON documents parse from the rendered ConfigMap |
| Bootstrap script | Extracted from rendered YAML, passes `sh -n` |
| Dashboard NDJSON | Valid JSON per line, no dangling references |
| Shell scripts under `ci/scripts/` | Pass `bash -n` |
| `ruff check` / `ruff format --check` | Clean |
| `detect-secrets` | 6 findings, all reviewed as false positives |

**Not verified, and why:**

- **`terraform validate`** — the build environment could not reach
  `registry.terraform.io`, so no provider could be downloaded and `init` could
  not run. The reference analysis above is a stand-in that catches undefined
  variables, dangling resource references and bad module wiring, but it does
  not type-check against the provider schema.
- **`terraform apply`** — no OCI tenancy. No resource in this repository has
  ever been created.
- **`tflint`** — its plugins are fetched from GitHub, which the build
  environment could not reach.
- **The entire kind path** — no Docker daemon in the build environment. The
  manifests render and the scripts parse, but nothing has been applied to a
  running cluster. Whether ECK accepts these custom resources, whether
  Filebeat's autodiscover config is valid, and whether logs actually arrive is
  proven by the CI integration job, not by anything run so far.
- **Kibana dashboard import** — the NDJSON was generated programmatically
  rather than exported from a live Kibana. Structure is validated; acceptance
  is not.

## Not in the repository yet

| Piece | Status |
|---|---|
| `apps/sample-api` — sample workload | Not written |
| `tools/oci-inventory` — governance CLI | Not written |
| `.github/workflows/` — GitHub Actions | Not written |
| `.gitlab-ci.yml` — GitLab pipeline | Not written |
| `docs/decisions/` — ADRs | Not written |
| `README.md` | Still a stub |

`make lint` and `make test` discover Python projects with a glob rather than a
fixed list, so they pass today and will pick those projects up as they land.
