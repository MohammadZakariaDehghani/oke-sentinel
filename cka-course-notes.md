# CKA Course Notes — Days 1 to 37

**Exam:** Tuesday 27 October 2026 · **Version:** Kubernetes v1.35 · **Pass mark:** 66/100
**Schedule:** weekdays only, 07:00–09:00 America/Vancouver, 1 Sept – 26 Oct 2026

**Domain weights:** Troubleshooting 30% · Cluster Architecture 25% · Services & Networking 20% · Workloads & Scheduling 15% · Storage 10%

---

## How to use this file

This is a **record of lessons already delivered**, not a textbook to read ahead in. Each day is added after the session. Reading Day 14 before you have built a cluster produces recognition without understanding — that feels like learning and isn't.

Three real uses:

1. **Review before a session.** Skim the previous day's Common Mistakes and Speed Tips.
2. **Look up a command you half-remember** during a lab.
3. **Final review on 26 October.** Go through every 🔥 item and confirm you can produce it from memory.

🔥 = memorise. Everything else you look up in the docs during the exam.

---

## Progress Tracker

| Day | Date | Topic |
|---|---|---|
| 1 | Tue 1 Sep | Setup + Cluster Architecture & Pods |
| 2 | Wed 2 Sep | ReplicaSets, Deployments, Namespaces, Imperative kubectl |
| 3 | Thu 3 Sep | ConfigMaps & Secrets |
| 4 | Fri 4 Sep | **LAB** — Output formats, JSONPath, speed drill |
| 5 | Tue 8 Sep | Multi-container, init containers, Jobs & CronJobs |
| 6 | Wed 9 Sep | Labels, manual scheduling, taints & tolerations |
| 7 | Thu 10 Sep | Affinity, resources, quotas, priority |
| 8 | Fri 11 Sep | **LAB** — DaemonSets, static pods, HPA → *Workloads 15% closed* |
| 9 | Mon 14 Sep | Control plane deep dive |
| 10 | Tue 15 Sep | kubeadm init & join |
| 11 | Wed 16 Sep | Node lifecycle + control plane upgrade |
| 12 | Thu 17 Sep | Worker upgrade, end-to-end |
| 13 | Fri 18 Sep | **LAB** — Build + upgrade a cluster, timed |
| 14 | Mon 21 Sep | etcd architecture & backup |
| 15 | Tue 22 Sep | etcd restore |
| 16 | Wed 23 Sep | RBAC: Roles, Bindings, ClusterRoles |
| 17 | Thu 24 Sep | ServiceAccounts, certificates, kubeconfig |
| 18 | Fri 25 Sep | **LAB** — etcd no-docs, RBAC, security contexts |
| 19 | Mon 28 Sep | Helm |
| 20 | Tue 29 Sep | Kustomize |
| 21 | Thu 1 Oct | CRDs & Operators |
| 22 | Fri 2 Oct | **LAB** — Cluster Architecture review → *25% closed* |
| 23 | Mon 5 Oct | Volumes, PV & PVC |
| 24 | Tue 6 Oct | StorageClasses → *Storage 10% closed* |
| 25 | Wed 7 Oct | Services, endpoints, kube-proxy |
| 26 | Thu 8 Oct | CoreDNS & DNS debugging |
| 27 | Fri 9 Oct | **LAB** — Services + DNS break/fix |
| 28 | Tue 13 Oct | Ingress & ingress controllers |
| 29 | Wed 14 Oct | Gateway API |
| 30 | Thu 15 Oct | NetworkPolicies |
| 31 | Fri 16 Oct | **LAB** — CNI + networking review → *Networking 20% closed* |
| 32 | Mon 19 Oct | Troubleshooting: apps, pods, debug toolkit |
| 33 | Tue 20 Oct | Troubleshooting: nodes, kubelet, control plane |
| 34 | Wed 21 Oct | **MOCK EXAM #1** |
| 35 | Thu 22 Oct | Mock #1 review + weak areas |
| 36 | Fri 23 Oct | **MOCK EXAM #2** |
| 37 | Mon 26 Oct | Final review (light) |
| — | **Tue 27 Oct** | **EXAM DAY** |

**Holidays excluded:** Mon 7 Sep (Labour Day) · Wed 30 Sep (Truth & Reconciliation) · Mon 12 Oct (Thanksgiving)

**Sessions delivered live so far:** Days 1–3. Days 4–37 below are written up in advance at slightly tighter depth — the live session for each day goes deeper, with labs whose answers are withheld until you attempt them.

---
---

# DAY 1 — Environment Setup + Cluster Architecture & Pods

## Environment check

Run these on your cluster before anything else:

```bash
kubectl version
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

## Goal

Two things, neither of which looks like "learning Kubernetes," both of which move your score.

**Terminal setup.** You get ~6 minutes per exam task. An unprepared terminal costs ~30 seconds each time — across 16 questions that is about 8 minutes, a whole task and a half.

**The component chain.** This is the backbone of the Troubleshooting domain (30%, the largest slice). Every troubleshooting task reduces to one question: *which link in this chain broke?*

## Concept

### The break from Docker

In Docker, `docker run nginx` **starts a container**. The command does the work.

In Kubernetes, `kubectl run nginx --image=nginx` starts nothing. It writes a **record of your intent** into a database. Independent processes then notice that record and react.

Nobody is in charge. Each component watches for work that concerns it and moves reality toward the record. This is **reconciliation**, and every controller in the system does the same three things: observe actual state, compare to desired state, close the gap.

### The five-stage chain 🔥

**Stage 1 — kubectl → kube-apiserver.** The API server is the only component that talks to the database. Everything passes through it.

**Stage 2 — apiserver → etcd.** Authenticates you, checks RBAC, runs admission controllers, writes the Pod object. At this moment the Pod exists on paper with no node assigned.

**Stage 3 — kube-scheduler.** Watches for Pods with an empty `nodeName`. Filters nodes (enough CPU? tolerates the taints?), scores survivors, picks a winner, tells the API server.

**Stage 4 — kubelet.** The kubelet on the chosen node sees a Pod assigned to it and calls the container runtime (containerd) over CRI to pull the image and start the container.

**Stage 5 — status report.** kubelet reports back to the API server, which writes to etcd. That is what `kubectl get pods` shows you.

Meanwhile **kube-controller-manager** runs dozens of control loops — node controller, replicaset controller, and more.

**kube-proxy** runs on every node and programs the iptables rules that make Services work. Networking component, not control plane.

The control plane itself runs as **static pods** — YAML files in `/etc/kubernetes/manifests` on the control-plane node. The kubelet watches that directory directly. This is why you fix a broken API server by **editing a file**, not with `kubectl`.

### Pods

One or more containers sharing a network namespace, able to share volumes. Containers inside a Pod reach each other on `localhost` and cannot bind the same port twice.

Useful framing: **a Pod is what a container would be if it had been designed for scheduling.** Smallest unit Kubernetes places on a node.

**Pod phases:**

| Phase | Meaning |
|---|---|
| `Pending` | Accepted but not running — usually unscheduled, or pulling an image |
| `Running` | Bound to a node, at least one container running |
| `Succeeded` | All containers terminated successfully |
| `Failed` | At least one container terminated in failure |
| `Unknown` | Node communication lost |

**Container states** are separate: `Waiting` (with a reason like `ImagePullBackOff`), `Running`, `Terminated` (with an exit code).

The phase gives you the neighbourhood. The container state gives the street address.

### The fact that makes Kubernetes click

**A bare Pod never recovers.** If its node dies, the Pod is gone permanently. `restartPolicy` only restarts a container *on the same node* — it never relocates anything. So something else must own the Pod.

## CKA Perspective

🔥 **Memorise the five-stage chain.** It is the mental map for the whole Troubleshooting domain:

- `Pending` → stages 1–2 succeeded, stage 3 did not → **scheduler** (resources, taints, affinity)
- Has a node but not running → **stage 4** → kubelet, runtime, or image
- `kubectl` doesn't respond → **stage 1** → API server down, go to `/etc/kubernetes/manifests`

🔥 **The two export lines.** In the exam, `k` and completion are pre-configured. These are not:

```bash
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
```

Since the February 2025 exam change, each question puts you on a different SSH node. Your exports die on every hop — expect to retype them.

**Not worth memorising:** YAML structure. kubernetes.io is open during the exam.

**Biggest time-loser:** omitting `-n <namespace>`.

## Commands

```bash
alias k=kubectl
complete -o default -F __start_kubectl k
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
```

```bash
# ~/.vimrc — YAML forbids tab characters, so expandtab is mandatory
set expandtab
set tabstop=2
set shiftwidth=2
set number
```

| Command | What it does / when to use |
|---|---|
| `k get nodes -o wide` | Nodes with IP, OS, kernel, runtime. First command on any unfamiliar cluster. |
| `k get pods -n kube-system` | Control plane + add-ons. If etcd/apiserver/scheduler/coredns isn't Running, stop looking at the app. |
| 🔥 `k describe po NAME` | Spec, container states, and the **Events** section. Read Events bottom-up. |
| `k get po NAME -o yaml` | The object as stored, including fields Kubernetes filled in (`nodeName`, `status`). |
| 🔥 `k explain pod.spec.containers` | Offline field docs, always version-correct. |
| `k explain pod.spec --recursive` | Whole subtree, no descriptions — use when you need the nesting. |
| `k api-resources` | Every kind + apiVersion + whether namespaced. |
| `k run web --image=nginx` | The **only** imperative command that creates a Pod. |
| `k delete po NAME $now` | Skips the 30-second grace period. |

## Troubleshooting Thinking

```text
1. k get pods -o wide
   → What phase? Which node? Does it have a node at all?

2. Pending             → scheduler (stage 3)
   Has node, not Running → kubelet / runtime (stage 4)
   Running but broken   → application

3. k describe po NAME    → Events, bottom up
4. k logs NAME           → if crashed: k logs NAME --previous
5. k get events --sort-by=.metadata.creationTimestamp
6. k exec -it NAME -- sh → mounts, env, connectivity
```

**Rule: `describe` before `logs`.** If the container never started, there are no logs.

## ⚠️ Common Mistakes

1. **Forgetting `-n`.** Resource is correct and lives in `default` instead of where the task asked.
2. **No `expandtab` in vimrc.** vim inserts tabs, YAML rejects them, and the error blames the wrong line.
3. **Running `logs` before `describe`.** If the container never started, `logs` errors out and you look in the wrong place.
4. **Writing YAML from scratch.** Generate with `$do`, then edit.
5. **Assuming `kubectl run` behaves like `docker run`.** `run` only makes Pods.

## Speed Tips

```bash
k run nginx --image=nginx $do > pod.yaml    # generate then edit — never an empty file
k explain pod.spec.containers.resources --recursive   # faster than the docs site
k get po -o wide                             # make -o wide your default
k get events --sort-by=.metadata.creationTimestamp    # always sort
k delete po web $now
```

## Mini Quiz

1. Which component notices a Pod has an empty `nodeName`?
2. A Pod is `Pending`. Which stages completed?
3. `apiVersion` for a Pod? For a Deployment?
4. You edit YAML in vim without `expandtab`. What breaks, and why is the error misleading?
5. `kubectl` returns "connection refused." Which stage failed, and where do you look?
6. What does `restartPolicy: Always` guarantee — and what does it *not*?
7. Why can two containers in one Pod not both bind port 8080?
8. Name three things `describe pod` shows that `get pod` does not.

## Daily Challenge

> From a clean terminal, configure your environment entirely from memory. Create namespace `chain`, then Pods `good` (nginx) and `bad` (nginx:v99). Without `describe`, write a **single command** showing both Pods, their phase, and their node. Explain in one sentence per Pod which stage of the chain each reached. Write both explanations to `/tmp/day1-answer.txt`. Clean up with one command.
>
> **Constraint:** every command uses `k`, never `kubectl`.

---
---

# DAY 2 — ReplicaSets, Deployments, Namespaces & Imperative kubectl

## Goal

Day 1 ended on a problem: a bare Pod never recovers. Today we meet the objects that fix that, plus the workflow that makes you fast enough to finish.

## Concept

### ReplicaSets — the control loop

A ReplicaSet does one thing: **make sure exactly N Pods matching this selector exist.**

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web          # how it FINDS pods it owns
  template:
    metadata:
      labels:
        app: web        # what it STAMPS on pods it creates
    spec:
      containers:
      - name: nginx
        image: nginx
```

Labels appear in **two places** and must agree. If they disagree, the ReplicaSet creates Pods, fails to recognise them, creates more, forever. The API server rejects this at creation — but a mismatch introduced by *editing* is a classic broken-cluster scenario, and the fix is always to compare those two blocks.

Because it counts by label, a ReplicaSet will **adopt** a pre-existing Pod with matching labels. Ownership is by label, not parentage.

### Deployments — managing change

```
Deployment  →  ReplicaSet  →  Pods
```

You will almost never create a ReplicaSet by hand.

**Why the middle layer exists:** when you update the image, the Deployment does not edit running Pods. It creates a **new ReplicaSet** with the new template, then scales the new one up while scaling the old one down. The old ReplicaSet survives at 0 replicas — and that is precisely what makes rollback possible.

- **`CHANGE-CAUSE` is empty unless you set it.** `--record` is deprecated; it's the `kubernetes.io/change-cause` annotation.
- **`rollout undo` creates a *new* revision.** Undoing revision 2 produces revision 3 that looks like revision 1. Revision numbers only go up.
- **`revisionHistoryLimit`** (default 10) controls how many old ReplicaSets are kept. Set to 0 and rollback silently stops working.

### Reading the Deployment status line

```
NAME   READY   UP-TO-DATE   AVAILABLE   AGE
web    3/3     3            3           15s
```

- **READY** — Pods passing readiness checks
- **UP-TO-DATE** — Pods running the *current* template
- **AVAILABLE** — ready Pods that stayed ready long enough to count

`3/3  1  3` = rollout stuck partway. `0/3  3  0` = application problem, not a Kubernetes one.

**Pod name decoding:** `web-6b7f9c8d4-2xk9p` = deployment + template-hash (the ReplicaSet's identity) + Pod instance. Two hashes during a rollout means two template versions live at once.

### Namespaces

Four exist by default: `default`, `kube-system`, `kube-public`, `kube-node-lease`.

**Not everything is namespaced.** Nodes, PersistentVolumes, StorageClasses, ClusterRoles, and Namespaces themselves are cluster-scoped.

**Namespaces appear in DNS:** `svc-name.namespace.svc.cluster.local`.

**`k get all` lies a little.** It shows Pods, Services, Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs. It does **not** show ConfigMaps, Secrets, PVCs, Ingresses, or ServiceAccounts.

### The imperative workflow 🔥

```bash
k create deploy web --image=nginx $do > web.yaml
vim web.yaml
k apply -f web.yaml
```

**`kubectl run` creates Pods. `kubectl create` creates everything else.**

Some fields have no imperative flag — volumes, probes, securityContext, tolerations. Generate the skeleton, then find the field with `k explain`.

Some fields are **immutable**. You cannot change a Deployment's `spec.selector` or most of a running Pod's spec. `k edit` lets you type the change then rejects it on save. Use force-replace:

```bash
k get po web -o yaml > web.yaml
vim web.yaml
k replace --force -f web.yaml     # delete and recreate in one step
```

## CKA Perspective

🔥 **The generate-then-edit workflow.** Typing boilerplate by hand costs ~90 seconds per task and you will get it wrong at least once.

🔥 **`-n` on every command.** Explicit beats implicit when you're tired and rushing.

**Commands you must produce without thinking:**

```bash
k create deploy NAME --image=IMG --replicas=3 -n NS
k scale deploy NAME --replicas=5 -n NS
k set image deploy/NAME CONTAINER=IMAGE -n NS
k rollout status|history|undo deploy/NAME -n NS
```

**apiVersion values:** `apps/v1` for Deployments, ReplicaSets, DaemonSets, StatefulSets. `v1` for Pods, Services, ConfigMaps, Secrets, Namespaces. `batch/v1` for Jobs and CronJobs.

## Commands

| Command | What it does / when to use |
|---|---|
| 🔥 `k create deploy web --image=nginx --replicas=3` | Your default. Never hand-write the YAML. |
| `k get all` | Whole ownership chain at once. Omits ConfigMaps, Secrets, PVCs. |
| `k get rs` | Use **during a rollout** — two ReplicaSets trading replicas confirms progress. |
| 🔥 `k scale deploy web --replicas=5` | Faster than editing YAML. |
| 🔥 `k set image deploy/web nginx=nginx:1.25` | Syntax is `CONTAINER=IMAGE`, not the deployment name. |
| 🔥 `k rollout status deploy/web` | Blocks until done or failed. Confirms rather than guesses. |
| `k rollout history deploy/web --revision=2` | Inspect before rolling back. |
| 🔥 `k rollout undo deploy/web --to-revision=1` | What the 0-replica ReplicaSets exist for. |
| `k annotate deploy/web kubernetes.io/change-cause="..."` | Sets CHANGE-CAUSE. `--record` is deprecated. |
| `k rollout restart deploy/web` | Recreates Pods, same template. How you pick up a changed ConfigMap. |
| `k config set-context --current --namespace=dev` | Switch default namespace. |
| `k config view --minify \| grep namespace` | 🔥 **Verify** the switch took. |
| `k get pods -A` | Your search tool when you don't know the namespace. |
| `k api-resources --namespaced=false` | Cluster-scoped resources. Read this output once. |
| `k replace --force -f pod.yaml` | Delete and recreate in one step, for immutable fields. |

## Troubleshooting Thinking

Work **down the ownership chain**. Never guess a layer.

```text
1. k get deploy -n NS
   → READY / UP-TO-DATE / AVAILABLE. Which number is wrong?

2. k get rs -n NS
   → One RS or two? Two = rollout in progress or stuck.
   → New RS with DESIRED > CURRENT? Pods aren't being created.

3. k get po -n NS -o wide
   → Pending (scheduler) or not Running (kubelet)?

4. k describe po <failing-pod> -n NS   → Events, bottom up
5. k describe rs <new-rs> -n NS
   → If Pods aren't appearing at all, the RS events say why
   → Quota exceeded, failed to create, admission denied
```

**Rule: if Pods don't exist, describe the ReplicaSet. If Pods exist but are broken, describe the Pod.**

## ⚠️ Common Mistakes

1. **Forgetting `-n`.** Still the top point-loser.
2. **`set image` syntax backwards.** It's `CONTAINER=IMAGE`. Check the container name with `k get deploy web -o jsonpath='{.spec.template.spec.containers[*].name}'`.
3. **Expecting CHANGE-CAUSE to appear by itself.** You must annotate.
4. **`k edit` on immutable fields.** Edits land in a temp file and you lose 90 seconds.
5. **Deleting a ReplicaSet expecting Pods to go.** The Deployment recreates it immediately. Delete the Deployment.
6. **Trusting a context switch.** You set it on a *different SSH node* three questions ago.

## Speed Tips

```bash
k create deploy web --image=nginx --replicas=3 $do > d.yaml
k get deploy,rs,po -n dev                    # three types, one round trip
k get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'
k get rs -w                                  # watch a rollout in a second terminal
k delete deploy web --now
k delete ns dev                              # fastest lab cleanup — NEVER on the exam
```

## Mini Quiz

1. Why does a Deployment need ReplicaSets instead of managing Pods directly?
2. During a rolling update, `k get rs` shows two ReplicaSets. What do their counts tell you?
3. What are the two places labels appear in a ReplicaSet spec, and what does each do?
4. You set `revisionHistoryLimit: 0`. What breaks?
5. Difference between UP-TO-DATE and AVAILABLE?
6. Name three resource types that are **not** namespaced.
7. Does `k get all -n foo` show ConfigMaps? PVCs?
8. You run `k rollout undo` at revision 2. What revision are you on afterwards?
9. `apiVersion` for: Pod, Deployment, Job, Service?
10. How would you change a Pod's `nodeName` after creation, and why can't `k edit` do it?

## Daily Challenge

> Everything imperative. No YAML files, no `kubectl edit`.
>
> Namespaces `alpha` and `beta`. In `alpha`: Deployment `frontend`, `nginx:1.24`, 3 replicas. In `beta`: `backend`, `redis:7.0`, 2 replicas. Scale `frontend` to 6. Update `backend` to `redis:7.2` with change-cause `"minor version bump"`. Roll it back. Produce a **single command** listing every Pod in both namespaces with name, namespace, and node. Write the total Pod count to `/tmp/day2-count.txt`. Identify which ReplicaSet in `beta` has 0 replicas and explain why it still exists. Delete both namespaces with one command.
>
> **Time target: 12 minutes.**

---
---

# DAY 3 — ConfigMaps & Secrets

## Goal

First half of the Workloads domain (15%). The friendliest material on the exam.

**Real-world use:** one nginx image, three environments. Baking config into the image means three images and a rebuild per value change. ConfigMaps break that coupling.

ConfigMaps and Secrets are structurally near-identical — which is why people mix them up under pressure. Today is largely about the differences.

## Concept

### Four ConfigMap creation methods

```bash
k create cm app --from-literal=ENV=prod --from-literal=TIER=web
k create cm app --from-file=app.properties
k create cm app --from-file=mykey=app.properties
k create cm app --from-file=./config-dir/
k create cm app --from-env-file=app.env
```

- `--from-literal` — one key per flag
- `--from-file=FILE` — **filename becomes the key, entire file contents become the value**
- `--from-file=key=FILE` — same, but you choose the key
- `--from-file=DIR/` — each file becomes its own entry
- `--from-env-file` — file contains `KEY=value` lines, **each line becomes its own key**

> Take one 3-line file. `--from-file` gives you **one key** holding the whole file. `--from-env-file` gives you **three keys**. Same input, completely different object.

### Three consumption patterns

**Single key as env var:**
```yaml
env:
- name: APP_ENV              # variable name inside the container
  valueFrom:
    configMapKeyRef:
      name: app              # which ConfigMap
      key: ENV               # which key in it
```
The variable name and the key are independent. Read which name goes where.

**All keys as env vars:**
```yaml
envFrom:
- configMapRef:
    name: app
  prefix: CONFIG_            # optional
```
Keys that aren't valid env var names are **silently skipped**. A key with a dash (`FOO-BAR`) is skipped, with an event recorded. If a task says "the app can't see its config," check for dashes.

**As a volume — each key becomes a file, each value becomes its contents:**
```yaml
volumeMounts:
- name: config
  mountPath: /etc/nginx/conf.d
  readOnly: true
volumes:
- name: config
  configMap:
    name: nginx-config
```

Three volume behaviours:

- **Mounting a directory hides what was there.** Standard Linux mount behaviour. Mount over `/etc` and the container is dead.
- **`subPath` mounts a single file**, leaving the directory intact — but `subPath` files **never update**.
- **`items`** selects specific keys and lets you rename them.

### Update behaviour 🔥

- **Volume-mounted** ConfigMaps refresh automatically (kubelet sync delay, up to ~60s). The app still has to notice.
- **Environment variables never refresh.** Set at container start, and that's it.

"I changed the ConfigMap and nothing happened" has one answer:

```bash
k rollout restart deploy/web
```

A Pod referencing a nonexistent ConfigMap gets scheduled normally, then fails to start with `CreateContainerConfigError`. Scheduled but not starting = **stage 4**.

### Secrets

```bash
k create secret generic db --from-literal=user=root --from-literal=pass=s3cret
k create secret tls web-tls --cert=tls.crt --key=tls.key
k create secret docker-registry reg --docker-server=X --docker-username=U --docker-password=P
```

`generic` takes ConfigMap flags. `tls` uses `--cert`/`--key` (not `--from-file`) and produces fixed keys `tls.crt` and `tls.key`. `docker-registry` produces a single key `.dockerconfigjson`.

**base64 is encoding, not encryption.** Anyone with read access decodes it in one command. The real reason: Secret values can hold binary data, and base64 lets binary live inside YAML.

```bash
k get secret db -o jsonpath='{.data.pass}' | base64 -d
echo -n 's3cret' | base64
```

The `-n` matters. Without it you encode an invisible trailing newline and authentication fails silently.

**`stringData`** is plain text, write-only — you set values with it, reads come back under `data` base64-encoded. If a task hands you a manifest to fill in, this means zero base64 juggling.

**Three field-name differences from ConfigMaps:**

| Use | ConfigMap | Secret |
|---|---|---|
| Single key as env | `configMapKeyRef` | `secretKeyRef` |
| All keys as env | `configMapRef` | `secretRef` |
| Volume | `configMap:` → `name:` | `secret:` → `secretName:` |

That last one is genuinely inconsistent in the API and catches people every time.

Two behaviours beyond syntax:

- Secret volumes use **tmpfs** (in-memory), so data never touches disk. Verify: `k exec pod -- mount | grep tmpfs`.
- When injected via volume or env var, values are **decoded automatically**. You only deal with base64 when reading through the API.

**imagePullSecrets** — a fourth consumption path with no ConfigMap equivalent:
```yaml
spec:
  imagePullSecrets:
  - name: regcred
```
Note it sits at **Pod level**, not inside a container. This is how you fix `ImagePullBackOff` on a private image.

## CKA Perspective

🔥 **Imperative creation:**
```bash
k create cm NAME --from-literal=K=V --from-literal=K2=V2
k create secret generic NAME --from-literal=K=V
k create secret tls NAME --cert=FILE --key=FILE
```

🔥 **Updating an existing ConfigMap.** `k create` errors if it exists:
```bash
k create cm app --from-literal=K=newvalue $do | k replace -f -
```

🔥 **Env vars never refresh.** "Make the Pod pick up the new configuration" = `k rollout restart`.

**Not worth memorising:** YAML nesting for volumes and `valueFrom`. Generate, then `k explain --recursive`.

## Commands

| Command | What it does / when to use |
|---|---|
| 🔥 `k create cm app --from-literal=ENV=prod` | Default creation method. Chain the flag for more keys. |
| `k create cm app --from-file=nginx.conf` | Key is the filename, value is the whole file. |
| `k create cm app --from-env-file=app.env` | One key per line. |
| `k get cm app -o yaml` | **Always** inspect after creation — the file/env-file difference is invisible otherwise. |
| 🔥 `k create cm app --from-literal=K=new $do \| k replace -f -` | Update in one line, no file, no editor. |
| 🔥 `k create secret generic db --from-literal=password=x` | 90% of Secret tasks. |
| `k create secret tls web-tls --cert=c --key=k` | Needed again on Day 28 for Ingress TLS. |
| 🔥 `k get secret db -o jsonpath='{.data.password}' \| base64 -d` | Decode one value. |
| `echo -n 'value' \| base64` | Encode. The `-n` prevents an invisible newline. |
| `k explain pod.spec.volumes.secret` | Settles `name` vs `secretName` in three seconds. |
| 🔥 `k rollout restart deploy/web` | The only way env-var config refreshes. |
| `k exec POD -- env \| grep KEY` | Verify injection. Never assume it worked. |
| `k exec POD -- ls /etc/config` | Verify the volume mount. |
| `k exec POD -- mount \| grep tmpfs` | Confirm a Secret volume is in-memory. |

## Troubleshooting Thinking

```text
1. k get po -n NS
   → CreateContainerConfigError = Kubernetes can't build the container spec
   → CrashLoopBackOff = container started, app rejected the config

2. k describe po NAME -n NS
   → Events name the exact missing object AND key:
     "configmap 'x' not found"  vs  "couldn't find key 'y' in ConfigMap"
   → These are DIFFERENT problems with different fixes

3. k get cm,secret -n NS        → does the object exist at all?
4. k get cm NAME -o yaml -n NS  → does the specific KEY exist inside it?

5. If object and key both exist:
   → check the reference field name (configMapKeyRef vs configMapRef, name vs secretName)

6. Running but misbehaving:
   → k exec POD -- env      (did the var arrive?)
   → k exec POD -- ls PATH  (did the file arrive?)
   → Stale value? Env vars don't refresh → rollout restart
```

**"not found" = the object is missing. "couldn't find key" = the object exists but the key doesn't.** Reading that difference saves you from recreating something that already exists.

## ⚠️ Common Mistakes

1. **Confusing `--from-file` and `--from-env-file`.** Always `k get cm X -o yaml` to confirm.
2. **Swapping `configMapKeyRef` and `configMapRef`.** `KeyRef` under `env` for one key; `Ref` under `envFrom` for all.
3. **Using `name:` in a Secret volume.** Secrets want `secretName:`.
4. **Forgetting `-n` on `echo -n`.** Embeds a newline; authentication fails with no visible cause.
5. **Expecting env vars to update.** They never do. `subPath` mounts don't either.
6. **Mounting over a populated directory.** Originals disappear while mounted.
7. **Not verifying inside the container.** `Running` doesn't mean the config arrived where you intended.

## Speed Tips

```bash
k create cm app --from-literal=A=1 --from-literal=B=2 --from-literal=C=3
k create cm app --from-literal=K=new $do | k replace -f -
k run p1 --image=nginx $do > p.yaml          # then add env/volumes
k explain pod.spec.containers.env.valueFrom --recursive
k get secret db -o jsonpath='{.data.pass}' | base64 -d
k get cm,secret -n NS                        # both types, one call
```

## Mini Quiz

1. `--from-file=app.env` vs `--from-env-file=app.env` on the same 3-line file. How many keys each?
2. Which field goes under `env`, which under `envFrom` — for ConfigMap and for Secret?
3. A ConfigMap has key `DB-HOST`. You use `envFrom`. What happens?
4. You change a ConfigMap. Pod A mounts it as a volume, Pod B uses `envFrom`. Which sees the new value, and when?
5. What two fixed key names does `k create secret tls` produce?
6. Why is base64 used, given it provides no security?
7. What does `-n` do in `echo -n 'x' | base64`, and what breaks without it?
8. A Pod references a nonexistent ConfigMap. Phase? Container state? Which stage failed?
9. Difference in Events between "configmap not found" and "couldn't find key"?
10. Name the three field-name differences between mounting a ConfigMap and a Secret.

## Daily Challenge

> Generate-then-edit only.
>
> Namespace `orders`. ConfigMap `app-config` with `LOG_LEVEL=debug`, `MAX_RETRIES=5`, `REGION=us-west`. Secret `db-secret` with `DB_USER=admin`, `DB_PASS=Str0ngP@ss`. Deployment `api`, 2 replicas of `nginx:alpine`, that gets **all** ConfigMap keys as env vars, **only** `DB_PASS` as `DATABASE_PASSWORD`, and mounts the whole Secret read-only at `/etc/secrets`. Verify all three injections from inside a running Pod. Change `LOG_LEVEL` to `info` in one command, no file. Make running Pods pick it up. Prove they did. Write decoded `DB_USER` to `/tmp/day3.txt`. Clean up with one command.
>
> **Time target: 15 minutes.**

---
---

# DAY 4 — LAB: Output Formats & Speed Drill

**Friday lab. No new theory. Every Friday from here is hands-on.**

## Goal

Two skills that don't look like Kubernetes knowledge but decide whether you finish: extracting data in the exact format a task demands, and creating resources fast enough to have time left for the hard questions.

## Output formats

```bash
k get po -o wide                    # 🔥 node + IP. Make this your default.
k get po -o yaml
k get po --show-labels
k get po -l app=web                 # equality selector
k get po -l 'env in (dev,staging)'  # set-based
k get po -l 'env!=prod'             # negative
k get po --sort-by=.metadata.creationTimestamp   # 🔥
k get po --sort-by=.spec.nodeName
k get po -A                         # 🔥 -n takes ONE namespace; there is no list form
```

## JSONPath

Two forms, and tasks distinguish between them:

```bash
# Space-separated, one line
k get po -o jsonpath='{.items[*].metadata.name}'

# One per line — needs {range}...{end}
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'   # 🔥

# Filter expression
k get no -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Multiple fields per line
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'
```

**custom-columns is usually easier to get right under pressure:**

```bash
k get po -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image
k get po -o custom-columns=NAME:.metadata.name --no-headers
```

**Writing answers to files** — a common task shape:

```bash
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > /tmp/answer.txt
```

> 🔥 **Read the required format carefully.** Space-separated and newline-separated are different answers. `--no-headers` matters when the task says "only the names."

## Events

```bash
k get events --sort-by=.metadata.creationTimestamp    # 🔥 ALWAYS sort
k get events -A --field-selector type=Warning
k get events -n NS --field-selector involvedObject.name=mypod
```

Unsorted events are chronological chaos and you will misread them under pressure.

## Lab — build the environment

```bash
k create ns alpha; k create ns beta
k create deploy web --image=nginx:1.24 --replicas=3 -n alpha
k create deploy api --image=nginx:1.25 --replicas=2 -n alpha
k create deploy cache --image=redis --replicas=2 -n beta
k run standalone --image=busybox -n beta --command -- sleep 3600
k expose deploy web --port=80 -n alpha
k label po -n alpha -l app=web env=prod
k label po -n beta -l app=cache env=dev
```

## Query drills — 90 seconds each

1. Every Pod in `alpha` with its node
2. All Pods cluster-wide labelled `env=prod`
3. Pods in both namespaces sorted by creation time
4. Only the image names of every Pod in `alpha`, one per line
5. Table of name + node + image for `beta`
6. Every namespace name as a single space-separated line
7. All Warning events, most recent last
8. Every node's InternalIP
9. All Pod names in `alpha` written to `/tmp/alpha-pods.txt`, one per line
10. Pods in `alpha` **not** labelled `env=prod`

## Break/fix

**Scenario 1**
```bash
k set image deploy/web nginx=nginx:1.99-doesnotexist -n alpha
```
What state are new Pods in? Why are old Pods still running? How many replicas actually serve traffic? Fix it.

**Scenario 2**
```bash
k patch deploy api -n alpha -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"memory":"900Gi"}}}]}}}}'
```
Prove *why* the new Pods are Pending using only `describe`. Which stage failed?

**Scenario 3**
```bash
k delete rs -n beta -l app=cache
```
What happened, and why?

## Speed drill — 15 resources, 15 minutes

Clean slate (`k delete ns alpha beta`), then:

1. Namespace `drill`
2. Pod `p1`, nginx
3. Pod `p2`, busybox, `sleep 3600`
4. Deployment `d1`, nginx, 3 replicas
5. Deployment `d2`, redis, 2 replicas, label `tier=cache`
6. Scale `d1` to 5
7. ClusterIP service for `d1` on port 80
8. NodePort service for `d2` on port 6379
9. ConfigMap `cm1` with `ENV=prod` and `TIER=web`
10. Secret `sec1` with `password=hunter2`
11. Job `j1`, busybox, `echo hello`
12. CronJob `cj1`, busybox, every 5 min, `date`
13. ServiceAccount `sa1`
14. ResourceQuota `rq1`, 2 CPU / 2Gi
15. Update `d1` to `nginx:1.25` with change-cause `"drill upgrade"`

**Scoring:** under 12 min = ahead. 12–18 = on track. Over 20 = repeat this drill Monday.

## ⚠️ Common Mistakes

1. **Assuming `-n` takes a list.** It doesn't. Use `-A` plus a filter.
2. **Wrong output shape.** Space-separated vs newline-separated are different answers.
3. **Forgetting `--no-headers`** when a task wants only values.
4. **Reading unsorted events.**
5. **Using JSONPath when custom-columns would be faster and safer.**

---
---

# DAY 5 — Multi-Container Pods, Init Containers, Jobs & CronJobs

*(Mon 7 Sep is Labour Day — no session.)*

## Goal

Workloads domain, part 2. Patterns that appear in both build tasks and debugging tasks.

## Multi-container patterns

Containers in one Pod share a **network namespace** (reach each other on `localhost`, cannot reuse a port) and can share **volumes**.

Three named patterns:

- **Sidecar** — a helper alongside the main container. Log shipper, proxy, file syncer. Most common by far.
- **Adapter** — reshapes the main container's output into a standard format.
- **Ambassador** — proxies the main container's outbound connections.

```yaml
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ["sh","-c","while true; do date >> /data/index.html; sleep 5; done"]
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    emptyDir: {}
```

**Exam-relevant commands:**
```bash
k logs POD -c CONTAINER          # 🔥 without -c on a multi-container pod, kubectl errors
k exec -it POD -c CONTAINER -- sh
k get po POD -o jsonpath='{.spec.containers[*].name}'   # list container names
```

## Init containers

Run **in order**, each must **succeed** before the next starts, and all must finish before app containers begin.

```yaml
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh','-c','until nslookup db; do sleep 2; done']
  containers:
  - name: app
    image: nginx
```

Differences from regular containers: they always run to completion, they don't support readiness probes, and they restart the whole Pod if they fail (with `restartPolicy: Always`).

**States you will see:** `Init:0/2`, `Init:Error`, `Init:CrashLoopBackOff`.
**Debug:** `k logs POD -c INIT_CONTAINER_NAME` 🔥 — a Pod stuck at `Init:0/1` has no app-container logs at all.

## Jobs

```bash
k create job pi --image=perl -- perl -Mbignum -e 'print bpi(200)'
k create job manual --from=cronjob/nightly      # 🔥 trigger a cronjob now
```

Key fields:

| Field | Meaning |
|---|---|
| `completions` | How many successful Pods are needed |
| `parallelism` | How many run at once |
| `backoffLimit` | Retries before the Job is marked Failed (default 6) |
| `activeDeadlineSeconds` | Hard wall-clock limit; kills the Job |
| `ttlSecondsAfterFinished` | Auto-delete after completion |

🔥 **Job `restartPolicy` must be `OnFailure` or `Never`.** `Always` is rejected — a common validation error when you generate a Pod and convert it by hand.

## CronJobs

```bash
k create cj report --image=busybox --schedule="*/5 * * * *" -- date    # 🔥
```

Schedule is standard cron: `minute hour day-of-month month day-of-week`.

| Field | Meaning |
|---|---|
| `concurrencyPolicy` | `Allow` (default) / `Forbid` / `Replace` |
| `suspend` | `true` pauses scheduling without deleting |
| `startingDeadlineSeconds` | Skip a run if it's this late |
| `successfulJobsHistoryLimit` | Completed Jobs kept (default 3) |
| `failedJobsHistoryLimit` | Failed Jobs kept (default 1) |

```bash
k patch cj report -p '{"spec":{"suspend":true}}'
k get cj,jobs,po
```

## ⚠️ Common Mistakes

1. **`k logs` on a multi-container Pod without `-c`.** Errors out and you waste time.
2. **`restartPolicy: Always` on a Job.** Rejected at creation.
3. **Looking for app logs on a Pod stuck at `Init:0/1`.** There are none — check the init container.
4. **Quoting the cron schedule wrong.** `--schedule="*/5 * * * *"` needs the quotes or the shell expands the asterisks.
5. **Forgetting that init containers run sequentially.** If the second hangs, the first already succeeded.

## Lab

1. Build a two-container Pod sharing an `emptyDir`, where the sidecar writes and the main container serves.
2. Read logs from each container separately.
3. Create a Pod with two init containers, the second of which fails. Identify which one failed and why, using only `describe` and `logs`.
4. Create a Job with `completions=6`, `parallelism=2`. Watch how Pods appear.
5. Create a CronJob running every minute. After two runs, trigger a manual Job from it. Suspend it.
6. **Break/fix:** create a Job with a command that always exits 1. What does `backoffLimit` do? How long until it stops?

---
---

# DAY 6 — Labels, Manual Scheduling, Taints & Tolerations

## Goal

Half the scheduling confusion on the exam lives in the taint/affinity distinction. Get it straight today.

## Labels and selectors

```bash
k get po --show-labels                # 🔥
k label po web env=prod               # 🔥
k label po web env=staging --overwrite
k label po web env-                   # 🔥 remove (trailing dash)
k label po -l app=web env=prod        # bulk by selector
k label node node1 disk=ssd
k annotate po web note="text"
```

**Labels are for selection. Annotations are for metadata.** Selectors only work on labels.

## Manual scheduling

```yaml
spec:
  nodeName: node2        # bypasses the scheduler entirely
```
or
```yaml
spec:
  nodeSelector:
    disk: ssd            # scheduler still picks, but only from matching nodes
```

`nodeName` is how a Pod gets scheduled when **the scheduler is down** — a real exam scenario. If `kube-scheduler` is broken and a task says "get this Pod running," set `nodeName` directly.

## Taints and tolerations 🔥

**Taints repel. Tolerations permit. Node selectors and affinity attract.**

```bash
k taint node node1 key=value:NoSchedule       # 🔥
k taint node node1 key=value:NoSchedule-      # 🔥 remove (trailing dash)
k describe node node1 | grep -i taint         # 🔥
```

**Three effects:**

| Effect | Meaning |
|---|---|
| `NoSchedule` | No new Pods without a matching toleration |
| `PreferNoSchedule` | Soft — avoid if possible |
| `NoExecute` | No new Pods **and evicts existing ones** without a toleration |

```yaml
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
  # operator: "Exists" matches any value for that key
```

🔥 **A toleration is permission, not attraction.** A Pod that tolerates a taint may still land elsewhere. To force placement you need `nodeSelector` or `nodeAffinity` **as well**.

**Control plane taint** — this is why your Pods never land there:
```bash
k describe node <cp> | grep -i taint
# node-role.kubernetes.io/control-plane:NoSchedule
k taint nodes --all node-role.kubernetes.io/control-plane-    # untaint (single-node lab)
```

`tolerationSeconds` on a `NoExecute` toleration = how long the Pod may stay after the taint appears.

## ⚠️ Common Mistakes

1. **Expecting a toleration to place a Pod on a specific node.** It only permits. Combine with `nodeSelector`.
2. **Forgetting the trailing dash** when removing a taint or label.
3. **Using annotations in a selector.** Selectors only see labels.
4. **Not checking existing taints** before debugging a Pending Pod.
5. **Setting `nodeName` and expecting the scheduler to validate it.** It doesn't — an unschedulable `nodeName` leaves the Pod stuck with no useful event.

## Lab

1. Label three nodes differently. Schedule a Pod to a specific one with `nodeSelector`.
2. Taint a node `NoSchedule`. Create a Pod without a toleration — where does it go, and what does `describe` say if it can't go anywhere?
3. Add a matching toleration. Does the Pod now land on the tainted node? Explain what you observe.
4. Combine a toleration with a `nodeSelector` to force placement.
5. Apply a `NoExecute` taint to a node with running Pods. Watch what happens.
6. **Break/fix:** make a Pod unschedulable using a taint, then diagnose it using only `describe pod` and `describe node`.

---
---

# DAY 7 — Affinity, Resources, Quotas, Priority

## Goal

The other half of scheduling, plus the resource concepts that feed directly into Pending-pod troubleshooting.

## Node affinity

More expressive than `nodeSelector`. Two modes:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:      # hard requirement
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values: ["ssd"]
      preferredDuringSchedulingIgnoredDuringExecution:     # soft preference
      - weight: 1
        preference:
          matchExpressions:
          - key: zone
            operator: In
            values: ["us-west-1a"]
```

Operators: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`.

**`IgnoredDuringExecution`** means: once scheduled, a Pod stays even if the node's labels change. There is no "RequiredDuringExecution" yet.

## Pod affinity / anti-affinity

Schedules relative to **other Pods**, not nodes:

```yaml
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: web
          topologyKey: kubernetes.io/hostname
```

`topologyKey` is a **node label** that defines the domain. `kubernetes.io/hostname` = one per node. `topology.kubernetes.io/zone` = one per zone.

Anti-affinity with `topologyKey: kubernetes.io/hostname` is the standard "spread my replicas across nodes" pattern.

## Topology spread constraints

```yaml
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule    # or ScheduleAnyway
    labelSelector:
      matchLabels:
        app: web
```

`maxSkew` = the maximum allowed difference in Pod count between domains.

## Requests and limits 🔥

```yaml
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
```

- **`requests`** affect **scheduling** — the scheduler reserves this much.
- **`limits`** affect **runtime** — exceeding memory gets you `OOMKilled`; exceeding CPU gets you throttled, not killed.

**QoS classes** (assigned automatically, not set by you):

| Class | Condition | Evicted |
|---|---|---|
| `Guaranteed` | requests == limits for every container | Last |
| `Burstable` | requests set, but not equal to limits | Middle |
| `BestEffort` | neither set | First |

```bash
k get po NAME -o jsonpath='{.status.qosClass}'
```

## LimitRange and ResourceQuota

**LimitRange** — per-Pod/container defaults and bounds within a namespace:
```yaml
kind: LimitRange
spec:
  limits:
  - type: Container
    default:        {cpu: "500m"}    # applied if you set no limit
    defaultRequest: {cpu: "100m"}
    max:            {cpu: "1"}
    min:            {cpu: "50m"}
```

**ResourceQuota** — total consumption across a namespace:
```bash
k create quota rq --hard=cpu=2,memory=2Gi,pods=10
k describe quota -n NS
```

🔥 **If a ResourceQuota sets CPU or memory limits, every Pod in that namespace MUST specify requests and limits** or creation is rejected. The error appears on the **ReplicaSet**, not the Pod — because no Pod ever gets created. This is a classic exam trap: `k get po` shows nothing and you have to `k describe rs` to find out why.

## PriorityClass

```yaml
kind: PriorityClass
metadata:
  name: high
value: 1000000
globalDefault: false
```
Higher value wins. When a high-priority Pod can't schedule, the scheduler **preempts** (evicts) lower-priority Pods to make room.

## Metrics and autoscaling

```bash
k top nodes          # requires metrics-server
k top pods
k autoscale deploy web --min=2 --max=10 --cpu-percent=80
k get hpa
```

## ⚠️ Common Mistakes

1. **Confusing requests and limits.** Requests schedule; limits constrain.
2. **Looking at Pods when a quota blocks creation.** No Pod exists — `describe rs`.
3. **Wrong `topologyKey`.** It must be a label that actually exists on your nodes.
4. **Assuming CPU limits kill a Pod.** They throttle. Only memory limits kill.
5. **`k top` failing and assuming the cluster is broken.** metrics-server may simply not be installed.

## Lab

1. Create a Pod requiring `disk=ssd` via node affinity. Remove the label from all nodes — what happens?
2. Deploy 3 replicas with pod anti-affinity on hostname. Confirm they spread.
3. Create Pods of each QoS class. Verify with jsonpath.
4. Create a ResourceQuota with CPU limits, then a Deployment without resource specs. **Find the error** — note where it appears.
5. Add a LimitRange with defaults. Create the same Deployment again. Does it work now? Why?
6. **Break/fix:** make a Pod Pending three different ways — resources, taint, nodeSelector — and diagnose each using only `describe`.

---
---

# DAY 8 — LAB: DaemonSets, Static Pods, HPA + Break/Fix

**Friday lab. Workloads & Scheduling (15%) closes after today.**

## DaemonSets

One Pod per node, automatically. Used for log collectors, monitoring agents, CNI plugins, kube-proxy.

```yaml
apiVersion: apps/v1
kind: DaemonSet
spec:
  selector:
    matchLabels: {name: fluentd}
  template:
    metadata:
      labels: {name: fluentd}
    spec:
      containers:
      - name: fluentd
        image: fluentd
```

No `replicas` field — the node count *is* the replica count.

There's no `k create daemonset` command. 🔥 **Generate a Deployment and edit it:**
```bash
k create deploy fluentd --image=fluentd $do > ds.yaml
# change kind: Deployment → DaemonSet, delete spec.replicas, delete spec.strategy
```

DaemonSets get default tolerations so they run on tainted nodes including control planes. Restrict with `nodeSelector` if a task asks for "only some nodes."

## Static Pods 🔥

Defined by files in `/etc/kubernetes/manifests` on a node. The **kubelet watches that directory directly** — no API server, no scheduler involved.

```bash
ls /etc/kubernetes/manifests/       # etcd, kube-apiserver, kube-controller-manager, kube-scheduler
grep staticPodPath /var/lib/kubelet/config.yaml     # confirm the path
```

Create one:
```bash
k run static-web --image=nginx $do > /etc/kubernetes/manifests/static-web.yaml
# appears within seconds, named static-web-<nodename>
```

Delete one: **remove the file.** `k delete po` will not work — the kubelet recreates it immediately.

🔥 The `-<nodename>` suffix is how you recognise a static Pod in `k get po`. This is also why the control plane can be fixed without `kubectl`.

## HPA

```bash
k autoscale deploy web --min=2 --max=10 --cpu-percent=80
k get hpa
k describe hpa web
```
Requires metrics-server and requires the Deployment to have CPU **requests** set — without requests there's no percentage to compute against.

## Break/fix drills

**1. Unschedulable three ways.** Make a Pod Pending via (a) excessive resource requests, (b) a taint with no toleration, (c) a `nodeSelector` matching nothing. Diagnose each using only `describe pod` — note how the FailedScheduling message differs.

**2. Static pod that won't start.** Put a manifest with a typo into `/etc/kubernetes/manifests`. It never appears in `k get po`. Where do you look? (`journalctl -u kubelet`)

**3. DaemonSet missing a node.** Create a DaemonSet, then taint one node `NoSchedule`. Does the DaemonSet Pod still run there? Explain.

**4. HPA that won't scale.** Create an HPA against a Deployment with no resource requests. What does `describe hpa` show?

**5. Quota blocking creation.** Set a ResourceQuota, create a Deployment with no resources. `k get po` shows nothing. Find the error.

## Timed drill

15 minutes:
1. DaemonSet `logger` running busybox `sleep 3600` on every node
2. Restrict it to nodes labelled `role=worker`
3. A static Pod named `webstatic` on your control plane
4. Prove it's a static Pod without looking at the filesystem
5. Delete the static Pod correctly
6. Deployment with CPU requests + an HPA scaling 2→8 at 70%

---
---

# DAY 9 — Control Plane Deep Dive

**Cluster Architecture (25%) begins — the biggest build domain.**

## The components

| Component | Runs where | Job |
|---|---|---|
| `kube-apiserver` | control plane | The only thing that talks to etcd. All requests pass through it. |
| `etcd` | control plane | Key-value store. The single source of truth. |
| `kube-scheduler` | control plane | Assigns Pods to nodes |
| `kube-controller-manager` | control plane | Runs all the control loops |
| `cloud-controller-manager` | control plane | Cloud provider integration (optional) |
| `kubelet` | **every node** | Starts containers, reports status. Not a Pod — a systemd service. |
| `kube-proxy` | **every node** | Programs iptables/IPVS rules for Services |

🔥 **The kubelet is a systemd service, not a Pod.** Everything else on the control plane is a static Pod. This asymmetry is the single most important fact for Day 33 — you restart the kubelet with `systemctl`, but you fix the API server by editing a file.

## Static pod manifests

```bash
ls -l /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Read all four manifests line by line today. Things to notice:
- `--advertise-address`, `--secure-port` (6443)
- `--etcd-servers`, `--etcd-cafile`, `--etcd-certfile`, `--etcd-keyfile` (you need these paths on Day 14)
- `--service-cluster-ip-range`
- `hostPath` volumes mounting `/etc/kubernetes/pki` and `/var/lib/etcd`
- `livenessProbe` on each

## Certificate layout

```bash
ls /etc/kubernetes/pki/
ls /etc/kubernetes/pki/etcd/
kubeadm certs check-expiration
```

Key files: `ca.crt`/`ca.key` (cluster CA), `apiserver.crt`, `apiserver-kubelet-client.crt`, `etcd/ca.crt`, `etcd/server.crt`, `etcd/server.key`.

## kubeconfig files

```bash
ls /etc/kubernetes/*.conf
# admin.conf  controller-manager.conf  kubelet.conf  scheduler.conf
```

Each component authenticates with its own kubeconfig. `admin.conf` is what you copy to `~/.kube/config`.

## crictl 🔥

When `kubectl` doesn't work, you still have the container runtime:

```bash
crictl ps                       # running containers
crictl ps -a                    # including exited — 🔥 this is where a crashed apiserver shows up
crictl logs <container-id>      # 🔥
crictl pods
crictl inspect <container-id>
```

Learn these now. On Day 33 they're the only tool you'll have.

## Lab

1. Identify every control plane component and where it runs.
2. Find the API server's secure port without a browser.
3. Extract the etcd cert paths from the etcd manifest — write them down, you need them Day 14.
4. Find the pod network CIDR and the service CIDR.
5. Run `crictl ps -a` and match containers to Pods.
6. `systemctl status kubelet` and `journalctl -u kubelet --since "1 hour ago"` — read real kubelet logs.
7. **Break/fix:** stop the kubelet on a worker (`systemctl stop kubelet`). What happens to the node? To its Pods? How long before eviction? Restart and observe recovery.

---
---

# DAY 10 — kubeadm init & join

## Node prerequisites

Every node, before anything:

```bash
swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab       # 🔥 kubelet refuses to start with swap on

cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay && modprobe br_netfilter

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system
```

Then containerd with 🔥 **`SystemdCgroup = true`** in `/etc/containerd/config.toml`. This is the most common kubeadm failure — without it the kubelet and containerd disagree about cgroups and Pods crashloop with no obvious error.

## Init

```bash
kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=<IP>

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

Then a CNI plugin. 🔥 **Use Calico, not Flannel** — Flannel does not implement NetworkPolicy, and policies would silently do nothing (Day 30 becomes unteachable).

## Join

```bash
kubeadm token create --print-join-command      # 🔥 lost the join command? this regenerates it
kubeadm join <IP>:6443 --token <t> --discovery-token-ca-cert-hash sha256:<hash>
```

Tokens expire after 24h by default. The CA cert hash lets the joining node verify the control plane.

```bash
kubeadm reset                # tear a node back down
rm -rf /etc/cni/net.d $HOME/.kube/config
```

## Why a node won't join

| Symptom | Cause |
|---|---|
| Connection refused on 6443 | Firewall, or wrong advertise address |
| Token expired / invalid | Regenerate with `token create` |
| CA hash mismatch | Copied wrong, or the cluster was rebuilt |
| Node joins but stays `NotReady` | No CNI installed, or containerd cgroup mismatch |
| Preflight: swap enabled | `swapoff -a` |
| Preflight: port in use | A previous install — `kubeadm reset` first |

## Lab

1. Prep two nodes from scratch.
2. `kubeadm init` on one. Copy admin.conf.
3. `k get nodes` — why is it `NotReady`?
4. Install Calico. Watch it become Ready.
5. Join the worker.
6. Deliberately let the token expire (or delete it), then regenerate and join again.
7. **Break/fix:** `kubeadm reset` the worker and rejoin it, timed.

---
---

# DAY 11 — Node Lifecycle + Control Plane Upgrade

## Node lifecycle 🔥

```bash
k cordon NODE          # mark unschedulable, existing Pods stay
k drain NODE --ignore-daemonsets --delete-emptydir-data     # 🔥 memorise both flags
k drain NODE --ignore-daemonsets --force                    # --force for unmanaged bare Pods
k uncordon NODE
k delete node NODE
```

Why each flag exists:
- `--ignore-daemonsets` — DaemonSet Pods can't be evicted meaningfully (they'd be recreated), so drain refuses without this
- `--delete-emptydir-data` — drain refuses to destroy `emptyDir` data without explicit consent
- `--force` — bare Pods with no controller would be lost permanently

**Node conditions:** `Ready`, `MemoryPressure`, `DiskPressure`, `PIDPressure`, `NetworkUnavailable`.

```bash
k describe node NODE | grep -A10 Conditions
```

## Upgrade — order matters 🔥

Never skip a minor version. 1.35 → 1.36 → 1.37, never 1.35 → 1.37.

**Control plane:**
```bash
# 1. upgrade the kubeadm binary
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.36.0-1.1
apt-mark hold kubeadm

# 2. plan and apply
kubeadm upgrade plan
kubeadm upgrade apply v1.36.0

# 3. drain the node
k drain <cp-node> --ignore-daemonsets

# 4. upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.36.0-1.1 kubectl=1.36.0-1.1
apt-mark hold kubelet kubectl

# 5. restart and uncordon
systemctl daemon-reload && systemctl restart kubelet
k uncordon <cp-node>
```

🔥 The sequence to remember: **kubeadm binary → upgrade apply → drain → kubelet+kubectl → restart → uncordon.**

`apt-mark hold` exists so an unattended `apt upgrade` can't silently bump your cluster. Releasing the hold is always step one.

## Lab

1. Cordon a node. Create a Deployment — where do Pods land?
2. Drain it without the flags. Read the error. Add the flags one at a time until it works.
3. Uncordon and verify Pods can schedule again.
4. Check `kubeadm upgrade plan` output — what versions are available?
5. Upgrade your control plane one minor version, timed.
6. **Break/fix:** try `kubeadm upgrade apply` skipping two minor versions. Read the error.

---
---

# DAY 12 — Worker Upgrade, End-to-End

## Worker upgrade

Same shape, one command different:

```bash
# On the control plane:
k drain <worker> --ignore-daemonsets --delete-emptydir-data

# On the worker:
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.36.0-1.1
apt-mark hold kubeadm

kubeadm upgrade node                    # 🔥 NOT "upgrade apply" — that's control-plane only

apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.36.0-1.1 kubectl=1.36.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet

# Back on the control plane:
k uncordon <worker>
```

## Version skew rules

- kubelet may be **up to 3 minor versions older** than the API server, never newer
- kubectl may be one minor version either side
- Upgrade the control plane **first**, always

```bash
k get nodes                    # VERSION column shows kubelet version per node
kubectl version
```

## Full drill

Upgrade a 2-node cluster end to end, then repeat it without docs. Target: control plane in under 10 minutes, worker in under 5.

Write down every point where you hesitated. Those are Friday's drills.

## ⚠️ Common Mistakes

1. **`kubeadm upgrade apply` on a worker.** It's `upgrade node`.
2. **Forgetting `apt-mark unhold`.** The install silently does nothing and versions don't change.
3. **Skipping the drain.** Works, but a task that says "safely upgrade" expects drain/uncordon.
4. **Forgetting `systemctl daemon-reload`.**
5. **Upgrading workers before the control plane.**
6. **Not uncordoning at the end.** The node stays unschedulable and the task scores partial.

---
---

# DAY 13 — LAB: Build + Upgrade a Cluster, Timed

**Friday lab.**

## Drill 1 — bootstrap, timed

From two fresh nodes to a working 2-node cluster with a CNI. Target: 20 minutes.

## Drill 2 — full upgrade, no docs

One minor version, both nodes, correct order, drain and uncordon. Target: 15 minutes.

## Drill 3 — node removal and re-join

```bash
k drain worker --ignore-daemonsets --delete-emptydir-data
k delete node worker
# on the worker:
kubeadm reset -f && rm -rf /etc/cni/net.d
# then rejoin
```

## Break/fix

**1. Delete the CNI.** `k delete -f calico.yaml`. What happens to existing Pods? New ones? Restore it.

**2. Stop the kubelet on a worker.** How long until the node goes `NotReady`? What happens to its Pods, and after how long? (Default eviction timeout is 5 minutes.)

**3. Break containerd's cgroup setting.** Set `SystemdCgroup = false`, restart containerd. What symptom do you see? Where in the logs?

**4. Corrupt a static pod manifest.** Introduce a typo in `kube-scheduler.yaml`. What still works? What doesn't? How do you find the error when `k describe` can't help?

**5. Expired token.** Wait out or delete a token, then try to join. Recover.

## Exit check

You should be able to build a cluster and upgrade it without reading anything. If not, this drill repeats before Day 14.

---
---

# DAY 14 — etcd Architecture & Backup

**One of the highest-value repeatable tasks on the exam.**

## What etcd is

A distributed key-value store holding **all** cluster state. Every object you have ever created lives here. The API server is the only component that talks to it.

```bash
cat /etc/kubernetes/manifests/etcd.yaml
```

Read this file. You need three things from it:

```bash
grep -E 'cert-file|key-file|trusted-ca-file|listen-client-urls|data-dir' /etc/kubernetes/manifests/etcd.yaml
```

Typical values:
- `--cert-file=/etc/kubernetes/pki/etcd/server.crt`
- `--key-file=/etc/kubernetes/pki/etcd/server.key`
- `--trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt`
- `--listen-client-urls=https://127.0.0.1:2379,...`
- `--data-dir=/var/lib/etcd`

🔥 **Never memorise cert paths — read them from the manifest.** The exam may use non-default locations, and a task that gives you unusual paths is testing exactly this.

## Backup 🔥

```bash
ETCDCTL_API=3 etcdctl snapshot save /opt/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

Verify:
```bash
ETCDCTL_API=3 etcdctl snapshot status /opt/backup.db --write-out=table
```

If `etcdctl` isn't installed: `apt-get install -y etcd-client`.

Note: newer etcd defaults to API v3, so `ETCDCTL_API=3` is often unnecessary — but typing it never hurts and some exam images are older.

## Other useful etcdctl

```bash
ETCDCTL_API=3 etcdctl member list --endpoints=... --cacert=... --cert=... --key=...
ETCDCTL_API=3 etcdctl endpoint health --endpoints=... --cacert=... --cert=... --key=...
```

## Lab

1. Locate every cert path from the manifest. Write them down.
2. Take a snapshot. Verify with `snapshot status` — note the revision and key count.
3. Create 5 namespaces and a Deployment. Take a **second** snapshot.
4. Compare the two snapshots' key counts.
5. Repeat the backup three times until you can do it without looking.
6. Check etcd member list and endpoint health.

**Target: a verified backup in under 3 minutes, from memory.**

---
---

# DAY 15 — etcd Restore

**The half people get wrong.**

## Restore is two steps 🔥

**Step 1 — restore the snapshot into a NEW directory:**
```bash
ETCDCTL_API=3 etcdctl snapshot restore /opt/backup.db \
  --data-dir=/var/lib/etcd-restore
```

The directory must not already exist. No certs needed for restore — you're writing local files, not talking to a server.

**Step 2 — point etcd at the new directory:**
```bash
vim /etc/kubernetes/manifests/etcd.yaml
```
Find the `hostPath` volume for `etcd-data` and change its path:
```yaml
  volumes:
  - hostPath:
      path: /var/lib/etcd-restore      # was /var/lib/etcd
      type: DirectoryOrCreate
    name: etcd-data
```

The kubelet notices the manifest changed and restarts etcd automatically. **No `systemctl`, no `kubectl apply`.**

🔥 **Step 2 is what people forget.** The restore command succeeds, they move on, and nothing changed because etcd is still reading the old data directory.

## Verifying

```bash
watch k get po -n kube-system         # etcd restarts, apiserver briefly unavailable
k get ns                              # is your pre-backup state back?
```

Expect 30–60 seconds of API unavailability. That's normal — don't panic and start changing things.

## Alternative approach

Some prefer keeping the path and moving directories instead:
```bash
systemctl stop kubelet
mv /var/lib/etcd /var/lib/etcd.old
mv /var/lib/etcd-restore /var/lib/etcd
systemctl start kubelet
```
Both work. Editing the manifest is fewer steps and is what most exam solutions expect.

## ⚠️ Common Mistakes

1. **Skipping step 2.** The single most common failure.
2. **Restoring into an existing directory.** etcdctl refuses.
3. **Passing certs to `snapshot restore`.** Not needed, and confusing when it errors.
4. **Panicking during the API outage.** Wait 60 seconds.
5. **Forgetting `--data-dir`.** It defaults to `default.etcd` in your CWD.

## Lab

1. Take a snapshot. Create namespaces `a`, `b`, `c`.
2. Restore from the snapshot. Are `a`, `b`, `c` gone? They should be.
3. Do it again, timed.
4. **Break/fix:** `rm -rf /var/lib/etcd/member`, restart the kubelet, watch the cluster die. Restore from your snapshot.
5. Do the whole backup+restore cycle twice more, no docs.

**Target: full cycle in under 8 minutes, from memory.**

---
---

# DAY 16 — RBAC: Roles, Bindings, ClusterRoles

## The model

Four objects, two axes:

| | Namespaced | Cluster-scoped |
|---|---|---|
| **Permissions** | `Role` | `ClusterRole` |
| **Grant** | `RoleBinding` | `ClusterRoleBinding` |

```bash
k create role dev --verb=get,list,watch --resource=pods -n dev              # 🔥
k create clusterrole node-reader --verb=get,list --resource=nodes
k create rolebinding dev-rb --role=dev --user=jane -n dev                   # 🔥
k create rolebinding dev-rb --role=dev --serviceaccount=dev:build-bot -n dev # 🔥
k create clusterrolebinding crb --clusterrole=node-reader --user=jane
```

**Verbs:** `get list watch create update patch delete deletecollection`. Wildcard `*`.

**API groups:** the core group is `""` (empty string) — Pods, Services, ConfigMaps, Secrets, Nodes. Named groups: `apps`, `batch`, `networking.k8s.io`, `rbac.authorization.k8s.io`.

```bash
k api-resources                # the APIVERSION column tells you the group
```

## The combination that confuses everyone 🔥

**A ClusterRole bound by a RoleBinding grants those permissions in ONE namespace only.**

That's the standard way to reuse a permission set across namespaces without granting it cluster-wide:

```bash
k create rolebinding read-pods --clusterrole=view --user=jane -n dev
# jane can now "view" — but only in dev
```

Cluster-scoped resources (nodes, PVs, namespaces) can **only** be granted through a ClusterRoleBinding. A RoleBinding can never grant access to a Node.

## Verification 🔥

```bash
k auth can-i get pods --as=jane -n dev
k auth can-i '*' '*' --as=jane
k auth can-i --list --as=jane -n dev
k auth can-i create deploy --as=system:serviceaccount:dev:build-bot -n dev
```

🔥 **Verify every RBAC task with `auth can-i`.** It takes 5 seconds and it's the only way to know you got it right. The ServiceAccount user format is `system:serviceaccount:<namespace>:<name>`.

## Built-in ClusterRoles

`cluster-admin`, `admin`, `edit`, `view`. A task saying "give read-only access" usually means binding `view`.

```bash
k get clusterroles
k describe clusterrole view
```

## Aggregated ClusterRoles

```yaml
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
```
Rules are collected from other ClusterRoles carrying that label. Don't edit an aggregated role's rules directly — they get overwritten.

## ⚠️ Common Mistakes

1. **Using a RoleBinding for a cluster-scoped resource.** Impossible. Nodes need a ClusterRoleBinding.
2. **Wrong API group.** Deployments are in `apps`, not `""`. Getting this wrong silently grants nothing.
3. **Wrong ServiceAccount format** in `--as`. It's `system:serviceaccount:NS:NAME`.
4. **Forgetting `-n` on the RoleBinding.** It's namespaced.
5. **Not verifying.** An RBAC task you didn't check with `auth can-i` is a coin flip.

## Lab

1. Create a Role allowing get/list on pods in `dev`. Bind it to user `jane`. Verify with `auth can-i`.
2. Extend it to Deployments. Note which API group you need.
3. Create a ClusterRole for nodes. Try binding it with a RoleBinding — what can jane do?
4. Now bind it with a ClusterRoleBinding. Verify.
5. Bind the built-in `view` ClusterRole to jane in `dev` only. Confirm she can't view `prod`.
6. **Break/fix:** given a user who "can't list pods," trace the chain: does the binding exist? does it reference the right Role? does the Role have the right verbs and group?

---
---

# DAY 17 — ServiceAccounts, Certificates, kubeconfig

## ServiceAccounts

How **Pods** authenticate (Users are for humans and are not Kubernetes objects — they come from certs or an external provider).

```bash
k create sa build-bot                                       # 🔥
k get sa
k create token build-bot                                    # short-lived token
k create token build-bot --duration=1h
```

```yaml
spec:
  serviceAccountName: build-bot
  automountServiceAccountToken: false      # opt out
```

🔥 **A Pod's ServiceAccount cannot be changed after creation.** If a task says "make this Pod use SA x," you must recreate the Pod — `k replace --force`.

Every namespace has a `default` SA, mounted into Pods at `/var/run/secrets/kubernetes.io/serviceaccount/` unless you opt out.

**imagePullSecrets on a ServiceAccount** get added automatically to every Pod using it:
```yaml
kind: ServiceAccount
imagePullSecrets:
- name: regcred
```

## Certificates and CSRs

Users authenticate with client certificates. `CN` becomes the username, `O` becomes the group.

```bash
# 1. Key and CSR
openssl genrsa -out jane.key 2048
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=developers"

# 2. Base64 the CSR (no line wrapping)
cat jane.csr | base64 -w 0
```

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: <base64 output>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
```

```bash
k get csr
k certificate approve jane                                              # 🔥
k certificate deny jane
k get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt   # 🔥
```

🔥 `-w 0` on the base64 encode. Line wrapping breaks the CSR and produces a confusing error.

## kubeconfig

Three sections plus a current context:

```bash
k config view
k config view --minify                       # only the current context
k config get-contexts
k config use-context NAME                    # 🔥 first command on every exam question
k config current-context

k config set-credentials jane --client-key=jane.key --client-certificate=jane.crt --embed-certs=true
k config set-cluster mycluster --server=https://1.2.3.4:6443 --certificate-authority=ca.crt --embed-certs=true
k config set-context jane-ctx --cluster=mycluster --user=jane --namespace=dev
k config use-context jane-ctx
```

`--embed-certs=true` inlines the cert instead of referencing a file path — makes the kubeconfig portable.

```bash
k --kubeconfig=/path/to/other.conf get pods       # use a specific file
```

## securityContext

Pod-level or container-level (container wins):

```yaml
spec:
  securityContext:              # pod level
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    securityContext:            # container level
      runAsUser: 2000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      privileged: false
      capabilities:
        add: ["NET_ADMIN"]
        drop: ["ALL"]
```

`fsGroup` sets group ownership on mounted volumes — only settable at Pod level.

## Lab

1. Create a SA, bind a Role to it, run a Pod with it, and from inside the Pod use the mounted token to call the API.
2. Try changing a running Pod's SA with `k edit`. Read the error. Do it correctly.
3. Full CSR flow: key → CSR → approve → extract cert → build kubeconfig → `auth can-i` as that user.
4. Create a Pod running as UID 1000 with all capabilities dropped. Verify with `k exec ... -- id`.
5. **Break/fix:** a Pod gets `Forbidden` errors. Trace SA → RoleBinding → Role and find the gap.

---
---

# DAY 18 — LAB: etcd No-Docs, RBAC Drills, Security Contexts

**Friday lab.**

## Drill 1 — etcd, no docs

Full backup and restore cycle, **twice**, timed. Target under 8 minutes each.

Then: `rm -rf /var/lib/etcd/member`, watch the cluster die, restore it.

## Drill 2 — RBAC, 5 tasks in 20 minutes

1. SA `ci` in `build` that can create and delete Jobs in `build` only
2. User `auditor` with read-only access to Pods and Deployments across **all** namespaces
3. SA `node-watcher` that can list Nodes (cluster-scoped)
4. User `dev1` with the built-in `edit` role in `dev` only
5. SA `secret-reader` that can read Secrets in `prod` but not `dev`

Verify **every one** with `auth can-i`.

## Drill 3 — security contexts

1. Pod running as UID 1000, GID 3000
2. Pod with a read-only root filesystem — then make it work by mounting an `emptyDir` at a writable path
3. Pod with `NET_ADMIN` added and everything else dropped
4. Two containers in one Pod running as different users

## Break/fix

**1.** Under-permission a SA, then diagnose the `Forbidden` message. What does the error tell you about the missing verb, resource, and group?

**2.** Bind a ClusterRole with a RoleBinding and have someone try to access a cluster-scoped resource. Why does it fail?

**3.** Wrong API group in a Role (`""` instead of `apps` for Deployments). No error at creation — how do you find it?

**4.** A Pod can't start because of `runAsNonRoot: true` with an image that runs as root. What's the event?

---
---

# DAY 19 — Helm

**New in the v1.35 curriculum. Mumshad's older sections may not cover it — use helm.sh/docs.**

## Concepts

- **Chart** — a package of templated manifests
- **Release** — an installed instance of a chart (you can install the same chart many times)
- **Values** — the configuration that fills the templates
- **Repository** — where charts live

## Commands

```bash
helm version
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update                              # 🔥 always after adding
helm repo list
helm search repo nginx
helm search repo nginx --versions             # all available chart versions

helm install myrel bitnami/nginx              # 🔥
helm install myrel bitnami/nginx -n web --create-namespace
helm install myrel bitnami/nginx --set replicaCount=3
helm install myrel bitnami/nginx --set image.tag=1.25,service.type=NodePort
helm install myrel bitnami/nginx -f values.yaml
helm install myrel bitnami/nginx --version 15.1.0

helm list                                     # 🔥 current namespace
helm list -A                                  # 🔥 all namespaces
helm status myrel
helm get values myrel                         # what this release was configured with
helm get manifest myrel                       # the rendered YAML actually applied

helm upgrade myrel bitnami/nginx --set replicaCount=5
helm upgrade --install myrel bitnami/nginx    # install if absent, upgrade if present
helm history myrel
helm rollback myrel 1
helm uninstall myrel

helm template myrel bitnami/nginx             # render locally, install nothing
helm show values bitnami/nginx                # every configurable value
helm pull bitnami/nginx --untar
```

🔥 **`helm show values`** is how you find out what you can `--set`. Without it you're guessing at key names.

## Chart structure

```
mychart/
  Chart.yaml          # name, version, appVersion
  values.yaml         # defaults
  templates/          # manifests with {{ }} placeholders
    deployment.yaml
    service.yaml
    _helpers.tpl
  charts/             # dependencies
```

## ⚠️ Common Mistakes

1. **Forgetting `helm repo update`** after adding a repo — search finds nothing.
2. **Guessing `--set` key names.** Use `helm show values` first.
3. **`--set` with nested values.** It's dot notation: `--set image.tag=1.25`.
4. **Forgetting `-n`.** Helm releases are namespaced like everything else.
5. **Using `helm install` when the release exists.** Use `upgrade --install`.

## Lab

1. Add a repo, update, search.
2. `helm show values` on a chart. Find the replica count key.
3. Install with a modified replica count via `--set`. Verify with `k get deploy`.
4. Upgrade to change the image tag. Check `helm history`.
5. Roll back. Confirm with `k get deploy` that the image reverted.
6. `helm template` the same chart — compare to `helm get manifest`.
7. Uninstall. Confirm every resource is gone.

---
---

# DAY 20 — Kustomize

**Also new v1.35 content. Built into kubectl — no separate install needed.**

## The idea

Kustomize applies **overlays** to **base** manifests without templating. Plain YAML, patched declaratively.

## kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namePrefix: prod-
nameSuffix: -v1
namespace: production

commonLabels:
  env: prod
commonAnnotations:
  owner: platform-team

images:
- name: nginx
  newTag: 1.25

replicas:
- name: web
  count: 5

configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=info

secretGenerator:
- name: db-secret
  literals:
  - password=s3cret

patches:
- path: patch.yaml
  target:
    kind: Deployment
    name: web
```

## Base and overlay layout

```
base/
  kustomization.yaml
  deployment.yaml
  service.yaml
overlays/
  dev/
    kustomization.yaml      # resources: [../../base]
  prod/
    kustomization.yaml
    patch.yaml
```

Overlay kustomization:
```yaml
resources:
- ../../base
namePrefix: prod-
replicas:
- name: web
  count: 10
```

## Commands

```bash
k kustomize ./overlays/prod          # 🔥 render to stdout, apply nothing
k apply -k ./overlays/prod           # 🔥 render and apply
k delete -k ./overlays/prod
k diff -k ./overlays/prod            # what would change
```

🔥 **Always `k kustomize` before `k apply -k`.** Rendering first catches mistakes for free.

## Generators and the hash suffix

`configMapGenerator` appends a content hash to the name (`app-config-7d9f2k`). Deployments referencing it get the hashed name substituted automatically — so **changing a value triggers a rolling update**, which is the fix for the "env vars never refresh" problem from Day 3.

Disable with:
```yaml
generatorOptions:
  disableNameSuffixHash: true
```

## ⚠️ Common Mistakes

1. **`bases:` instead of `resources:`.** `bases` is deprecated.
2. **Wrong relative path** to the base. It's relative to the kustomization file.
3. **Applying without rendering first.**
4. **Forgetting the hash suffix exists** and wondering why the ConfigMap name doesn't match.

## Lab

1. Build a base with a Deployment and Service.
2. Create `dev` and `prod` overlays with different prefixes and replica counts.
3. Render both. Diff them.
4. Apply `prod`. Verify names, labels, replicas.
5. Add a `configMapGenerator`. Note the hash suffix in the applied object.
6. Change a value, re-apply — confirm the Deployment rolls.
7. Write a patch that adds resource limits to only one Deployment.

---
---

# DAY 21 — CRDs & Operators

**Also new v1.35 content. Mostly read-and-inspect skills, not authoring.**

## CustomResourceDefinitions

A CRD teaches the API server a new `kind`.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backups.example.com          # MUST be <plural>.<group>
spec:
  group: example.com
  scope: Namespaced                  # or Cluster
  names:
    plural: backups
    singular: backup
    kind: Backup
    shortNames: [bk]
  versions:
  - name: v1
    served: true
    storage: true                    # exactly ONE version has storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              schedule: {type: string}
```

🔥 Two rules that produce validation errors: the metadata name must be exactly `<plural>.<group>`, and exactly one version may have `storage: true`.

## Inspecting

```bash
k get crd                                    # 🔥
k get crd backups.example.com -o yaml
k api-resources --api-group=example.com      # 🔥
k explain backup.spec                        # works on CRDs once installed
k get backups -A
k describe backup mybackup
```

## Operators

An operator is a **controller + one or more CRDs**. The controller watches custom resources and reconciles real-world state to match — the same observe/compare/act loop as every built-in controller.

To inspect an installed operator:
```bash
k get crd | grep <operator-name>
k get deploy -A | grep operator
k get clusterrole,clusterrolebinding | grep operator
k logs -n <ns> deploy/<operator>
```

## Finalizers 🔥

```yaml
metadata:
  finalizers:
  - example.com/cleanup
```

An object with a finalizer **cannot be deleted** until the controller removes the finalizer. If the controller is gone, the object hangs in `Terminating` forever — and so does its namespace.

This is the standard "namespace stuck Terminating" scenario:
```bash
k get ns stuck -o yaml            # look at spec.finalizers and status
k get all,crd -n stuck
# Fix: remove the finalizer from the blocking object
k patch <resource> <name> -n stuck -p '{"metadata":{"finalizers":null}}' --type=merge
```

## Lab

1. Apply a CRD. Confirm with `k get crd` and `k api-resources`.
2. Create custom resources. Query them with `k get` and short names.
3. Run `k explain` on your custom kind.
4. Install an operator via Helm. Trace every object it created — CRDs, Deployment, SA, ClusterRole.
5. Read the operator's logs during a reconcile.
6. **Break/fix:** add a finalizer to a custom resource, delete it, watch it hang. Recover the namespace.

---
---

# DAY 22 — LAB: Cluster Architecture Review

**Friday lab. Cluster Architecture (25%) closes after today.**

## Timed mixed drill — 60 minutes

1. etcd backup + restore, from memory (target 8 min)
2. Upgrade one node one minor version (target 10 min)
3. Create a SA with namespaced Job permissions, verified (target 5 min)
4. Full CSR flow to a working kubeconfig (target 10 min)
5. Install a chart with Helm, change a value, roll back (target 5 min)
6. Build a Kustomize overlay changing replicas and namespace (target 10 min)
7. Create a static Pod and prove it's static (target 3 min)

## Break/fix

**1.** Corrupt `kube-apiserver.yaml`. `kubectl` stops working entirely. Recover using only `crictl` and the filesystem.

**2.** Delete a control plane cert. What breaks? Regenerate with `kubeadm certs`.

**3.** Change the etcd data-dir to a nonexistent path. Diagnose and fix.

**4.** Under-permission a SA used by a Deployment. Find the `Forbidden` and fix it.

**5.** Restore etcd from a snapshot taken **before** you created several namespaces. Confirm they're gone.

## Exit checklist

Write down your **three weakest topics** in this domain. You will drill them on Day 35.

---
---

# DAY 23 — Volumes, PV & PVC

**Storage (10%). The smallest domain — make it airtight, these are free points.**

## Volume types

| Type | Lifetime | Use |
|---|---|---|
| `emptyDir` | Pod lifetime | Scratch space, sharing between containers in a Pod |
| `hostPath` | Node lifetime | Access node filesystem. Dangerous, but used by system Pods |
| `configMap` / `secret` | — | Config injection (Day 3) |
| `persistentVolumeClaim` | Independent of Pod | Real persistence |

```yaml
  volumes:
  - name: cache
    emptyDir: {}
  - name: cache-in-ram
    emptyDir:
      medium: Memory          # tmpfs, counts against memory limits
  - name: hostlogs
    hostPath:
      path: /var/log
      type: Directory         # or DirectoryOrCreate, File, FileOrCreate
```

## PersistentVolume

Cluster-scoped. Represents actual storage.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-1
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  volumeMode: Filesystem
  hostPath:
    path: /mnt/data
```

## PersistentVolumeClaim

Namespaced. A request for storage.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-1
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
  storageClassName: manual
```

Then in the Pod:
```yaml
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-1
```

## Binding rules 🔥

A PVC binds to a PV only if **all** of these match:

1. `storageClassName` is identical (including both being empty)
2. `accessModes` requested are offered by the PV
3. PV `capacity` ≥ PVC `requests.storage`
4. `volumeMode` matches
5. The PV is `Available` (not already `Bound`)

A PV **larger** than requested still binds — you just get the extra. A PV smaller does not.

**Access modes:**

| Mode | Short | Meaning |
|---|---|---|
| `ReadWriteOnce` | RWO | One **node** can mount read-write |
| `ReadOnlyMany` | ROX | Many nodes, read-only |
| `ReadWriteMany` | RWX | Many nodes, read-write |
| `ReadWriteOncePod` | RWOP | One **Pod**, read-write |

🔥 RWO is per-**node**, not per-Pod. Two Pods on the same node can share an RWO volume.

**Phases:** PV goes `Available` → `Bound` → `Released` → `Failed`. PVC goes `Pending` → `Bound`.

🔥 A `Released` PV is **not** reusable. You must delete and recreate it (or clear `spec.claimRef`).

## Commands

```bash
k get pv,pvc                              # 🔥 PV is cluster-scoped, PVC is namespaced
k describe pvc NAME                       # 🔥 tells you exactly why it's Pending
k get pvc -o wide
k explain pv.spec --recursive
```

## Lab

1. Two-container Pod sharing an `emptyDir`. Write from one, read from the other.
2. Create a PV (hostPath, 5Gi, RWO, `storageClassName: manual`).
3. Create a matching PVC. Confirm both go `Bound`.
4. Mount it in a Pod, write a file, delete the Pod, recreate it — is the file still there?
5. Delete the PVC. What phase is the PV in now? Can a new PVC bind to it?
6. **Break/fix:** make a PVC stay Pending via (a) mismatched storageClassName, (b) requesting more than the PV offers, (c) requesting RWX when the PV offers RWO. Diagnose each with `describe pvc` only.

---
---

# DAY 24 — StorageClasses & Dynamic Provisioning

**Storage (10%) closes after today.**

## StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"    # 🔥 the default-class annotation
provisioner: kubernetes.io/no-provisioner                  # or a real CSI driver
parameters:
  type: gp3
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

```bash
k get sc                                  # 🔥 the default is marked "(default)"
k describe sc fast
```

## Dynamic vs static

- **Static** — you create PVs by hand, PVCs bind to them
- **Dynamic** — a PVC names a StorageClass, and a PV is created automatically

If a PVC omits `storageClassName` entirely, the **default StorageClass** is used. If there is no default, the PVC stays `Pending`. 🔥 Setting `storageClassName: ""` explicitly means "no class — static binding only."

## Key fields

| Field | Values | Meaning |
|---|---|---|
| `reclaimPolicy` | `Delete` / `Retain` | What happens to the PV when the PVC is deleted |
| `volumeBindingMode` | `Immediate` / `WaitForFirstConsumer` | Bind at PVC creation, or wait until a Pod uses it |
| `allowVolumeExpansion` | bool | Whether you can grow a PVC later |

`WaitForFirstConsumer` matters in multi-zone clusters — it delays provisioning until the scheduler picks a node, so the volume lands in the right zone. A PVC with this mode sitting `Pending` with no Pod is **normal**, not broken.

## Expanding a PVC

```bash
k edit pvc mypvc          # increase spec.resources.requests.storage
```
Only works if the StorageClass has `allowVolumeExpansion: true`. Shrinking is never allowed.

## PVC Pending — the five causes 🔥

1. No PV matches (class, size, accessMode, volumeMode)
2. No default StorageClass and the PVC didn't name one
3. The named StorageClass doesn't exist
4. `WaitForFirstConsumer` and no Pod is using it yet — **not an error**
5. The provisioner is broken or absent (`describe pvc` shows provisioning events)

```bash
k describe pvc NAME              # 🔥 the Events section names the exact cause
k get sc
k get pv
```

## ⚠️ Common Mistakes

1. **Omitting `storageClassName` and assuming static binding.** Omission means "use the default." Empty string means "no class."
2. **Panicking at a `Pending` PVC with `WaitForFirstConsumer`.** Create a Pod and it binds.
3. **Expecting a `Released` PV to be reusable.**
4. **Trying to shrink a PVC.**
5. **Forgetting `-n` on PVCs.** They're namespaced; PVs are not.

## Lab

1. `k get sc` — is there a default? Which provisioner?
2. Create a PVC with no `storageClassName`. What happens?
3. Create a StorageClass with `WaitForFirstConsumer`. Make a PVC — it stays Pending. Create a Pod — it binds. Explain.
4. Create a class with `reclaimPolicy: Delete`. Provision, then delete the PVC. Is the PV gone?
5. Same with `Retain`. What phase is the PV in?
6. Expand a PVC on a class that allows it. Then try on one that doesn't.
7. **Break/fix:** all five Pending causes, diagnosed with `describe pvc` alone.

---
---

# DAY 25 — Services, Endpoints, kube-proxy

**Services & Networking (20%) begins.**

## Service types

| Type | What it does |
|---|---|
| `ClusterIP` | Internal virtual IP. The default. |
| `NodePort` | ClusterIP **plus** a port on every node (30000–32767) |
| `LoadBalancer` | NodePort **plus** an external LB (cloud only) |
| `ExternalName` | A CNAME to an external DNS name. No proxying, no selector. |

Each type builds on the previous. A `LoadBalancer` Service still has a ClusterIP and a NodePort.

**Headless** = `clusterIP: None`. No virtual IP; DNS returns the Pod IPs directly. Used by StatefulSets.

## The three ports 🔥

```yaml
  ports:
  - port: 80              # the Service's own port
    targetPort: 8080      # the CONTAINER's port
    nodePort: 30080       # the port on every node (NodePort/LoadBalancer only)
```

Getting `port` and `targetPort` backwards is one of the most common exam errors. `port` is what clients connect to; `targetPort` is where the traffic goes.

## Creating

```bash
k expose deploy web --port=80 --target-port=8080          # 🔥 inherits the selector
k expose deploy web --port=80 --type=NodePort             # 🔥
k expose po mypod --port=80 --name=pod-svc
k create svc clusterip mysvc --tcp=80:8080                # no selector — you wire endpoints yourself
k create svc nodeport mysvc --tcp=80:8080 --node-port=30080
```

🔥 **Prefer `k expose`** over `k create svc`. It reads the selector off the target automatically, which removes the single most common source of broken Services.

## Endpoints — your #1 debugging tool 🔥

```bash
k get endpoints SVC          # 🔥
k get endpointslices
k describe svc SVC
```

A Service finds Pods by **label selector**. The controller writes matching Pod IPs into an Endpoints object.

**Empty endpoints = the selector matches nothing.** That is almost always the answer when a Service doesn't work.

```bash
k get svc web -o jsonpath='{.spec.selector}'
k get po --show-labels
# compare them
```

## kube-proxy

Runs on every node as a DaemonSet. Watches Services and Endpoints, programs iptables (or IPVS) rules that redirect ClusterIP traffic to real Pod IPs.

```bash
k get ds -n kube-system kube-proxy
k logs -n kube-system -l k8s-app=kube-proxy
iptables -t nat -L | grep <clusterip>
```

If kube-proxy is down: DNS still resolves, ClusterIPs still exist, and **nothing connects**. That specific combination is the signature.

## Debug order for any Service 🔥

```text
1. Does the Service exist?          k get svc -n NS
2. Does it have endpoints?          k get endpoints SVC -n NS
   → empty → selector mismatch → compare svc selector to pod labels
3. Do the Pods work directly?       k run tmp --rm -it --image=busybox -- wget -O- <POD_IP>:<PORT>
   → fails → application problem, not a Service problem
4. Is targetPort right?             does it match the container's actual port?
5. Does DNS resolve?                nslookup from a busybox pod
6. Is kube-proxy running?           k get po -n kube-system -l k8s-app=kube-proxy
```

## Lab

1. Deployment + `k expose`. Inspect the generated selector.
2. Reach it by ClusterIP from a busybox Pod.
3. NodePort version. Reach it via `<nodeIP>:<nodePort>`.
4. Headless Service. What does DNS return now?
5. ExternalName Service to `example.com`. Resolve it from a Pod.
6. **Break/fix:** change the Service selector so it matches nothing. Diagnose using endpoints only.
7. **Break/fix:** set `targetPort` to the wrong number. Endpoints exist but connections refuse. Explain why the symptom differs from case 6.

---
---

# DAY 26 — CoreDNS & DNS Debugging

## How DNS works here

CoreDNS runs as a Deployment in `kube-system`, fronted by a Service called `kube-dns` (the name is historical). Every Pod's `/etc/resolv.conf` points at that Service's ClusterIP.

```bash
k get deploy,svc,po -n kube-system -l k8s-app=kube-dns
k get cm coredns -n kube-system -o yaml        # 🔥 the Corefile
```

## Name formats 🔥

```
<service>                                    # same namespace
<service>.<namespace>
<service>.<namespace>.svc
<service>.<namespace>.svc.cluster.local      # 🔥 the full FQDN
```

Pods get `<pod-ip-with-dashes>.<namespace>.pod.cluster.local`, e.g. `10-244-1-5.default.pod.cluster.local`.

Headless Services return **all** Pod IPs. StatefulSet Pods additionally get `<pod-name>.<service>.<namespace>.svc.cluster.local`.

## resolv.conf

```bash
k exec POD -- cat /etc/resolv.conf
```
```
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

`ndots:5` means any name with fewer than 5 dots gets the search domains appended first. This is why `nslookup mysvc` works from inside a Pod but `nslookup mysvc` from a node does not.

## The debug loop 🔥

```bash
k run tmp --image=busybox:1.28 --rm -it --restart=Never -- sh
# inside:
nslookup kubernetes.default
nslookup my-svc
nslookup my-svc.my-ns.svc.cluster.local
wget -O- my-svc:80
cat /etc/resolv.conf
```

🔥 Use `busybox:1.28` specifically — later busybox images have a broken `nslookup` that fails on valid cluster names and will send you chasing a nonexistent DNS problem.

## dnsPolicy

| Value | Meaning |
|---|---|
| `ClusterFirst` | Default. Cluster DNS, falling back to upstream |
| `Default` | Inherit the node's resolv.conf — **no cluster DNS** |
| `None` | Use `dnsConfig` only |
| `ClusterFirstWithHostNet` | Needed when `hostNetwork: true` |

🔥 A Pod with `hostNetwork: true` and the default `dnsPolicy` cannot resolve cluster names. The fix is `dnsPolicy: ClusterFirstWithHostNet`.

## Failure modes

| Symptom | Cause |
|---|---|
| Nothing resolves anywhere | CoreDNS Pods down, or `kube-dns` Service broken |
| Resolves but wrong IP | Stale endpoints, or a duplicate Service |
| External names fail, cluster names work | Corefile `forward` misconfigured |
| One Pod can't resolve, others can | `dnsPolicy`, or a NetworkPolicy blocking egress to port 53 |
| Works by FQDN, not short name | `search` domains or `ndots` |

## Lab

1. Find CoreDNS: Deployment, Service, ConfigMap, Pods.
2. Read the Corefile. Identify the `forward` and `kubernetes` plugins.
3. From a busybox Pod, resolve a Service by all four name forms.
4. Read `/etc/resolv.conf` inside a Pod and explain each line.
5. **Break/fix:** scale CoreDNS to 0. What fails, and what still works? Restore.
6. **Break/fix:** edit the Corefile to break the `kubernetes` plugin. Diagnose from a Pod, then fix.
7. Create a Pod with `dnsPolicy: Default`. Try resolving a Service. Explain the result.

---
---

# DAY 27 — LAB: Services + DNS Break/Fix

**Friday lab.** *(Mon 12 Oct is Thanksgiving — no session.)*

## Timed build — 20 minutes

1. Deployment `web` (nginx, 3 replicas) + ClusterIP on 80
2. Deployment `api` (nginx, 2 replicas) + NodePort on 8080→80, nodePort 30080
3. Headless Service for `web`
4. ExternalName Service `ext` → `example.com`
5. Verify **every one** from a busybox Pod
6. Write all endpoint IPs of `web` to `/tmp/endpoints.txt`

## Break/fix — diagnose each in under 5 minutes

**1. Selector mismatch.** `k set selector svc/web app=wrong`. Symptom? Which command reveals it fastest?

**2. Wrong targetPort.** Point it at 8080 when nginx listens on 80. How does this symptom differ from case 1? (Endpoints **exist**, connections **refuse**.)

**3. CoreDNS down.** Scale to 0. Does the ClusterIP still work? Does the name?

**4. kube-proxy stopped.** Delete the DaemonSet. DNS resolves, ClusterIP exists, nothing connects. Why?

**5. NodePort out of range.** Try `nodePort: 25000`. Read the validation error.

**6. Pod not Ready.** Add a failing readiness probe. Watch endpoints drain. This is the mechanism behind rolling updates.

## The fixed order — internalise it

```text
1. Service exists?
2. Endpoints populated?     → empty = selector mismatch
3. Pod reachable directly?  → no = app problem
4. targetPort correct?      → endpoints exist but refused
5. DNS resolves?            → CoreDNS
6. kube-proxy running?      → resolves but no connection
```

Every Service failure on the exam is one of these six.

---
---

# DAY 28 — Ingress & Ingress Controllers

## The split 🔥

- **Ingress** — the rules. A Kubernetes object describing host/path → Service routing.
- **Ingress controller** — the software that reads those rules and actually routes traffic.

🔥 **An Ingress with no controller running does absolutely nothing.** No error, no event, just silence. This is a favourite exam scenario.

## The resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts: [shop.example.com]
    secretName: shop-tls
  rules:
  - host: shop.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
```

Note the nesting: `backend.service.name` and `backend.service.port.number`. This changed in `networking.k8s.io/v1` and older examples online are wrong.

## pathType 🔥

| Value | Meaning |
|---|---|
| `Prefix` | Matches by path **segment**. `/foo` matches `/foo/bar`, not `/foobar` |
| `Exact` | Exact string match, case-sensitive |
| `ImplementationSpecific` | Up to the controller |

`pathType` is **required**. Omitting it is a validation error.

## Imperative creation

```bash
k create ingress web --rule="shop.com/api*=api-svc:80"           # 🔥 the * means Prefix
k create ingress web \
  --rule="shop.com/api*=api-svc:80" \
  --rule="shop.com/*=web-svc:80" \
  --class=nginx
k create ingress secure --rule="shop.com/*=web-svc:80,tls=shop-tls"
```

🔥 The trailing `*` sets `pathType: Prefix`. Without it you get `Exact`.

## Commands

```bash
k get ing
k get ing -A
k describe ing NAME                    # 🔥 shows backends and whether they resolved
k get ingressclass
k get po -n ingress-nginx              # is the controller actually running?
k logs -n ingress-nginx deploy/ingress-nginx-controller
```

## TLS

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=shop.example.com"
k create secret tls shop-tls --cert=tls.crt --key=tls.key
```
Then reference `shop-tls` under `spec.tls[].secretName`. The Secret must be in the **same namespace as the Ingress**.

## Failure modes

| Symptom | Cause |
|---|---|
| Ingress exists, nothing happens | No controller installed |
| `ADDRESS` column empty | Controller not ready, or no LoadBalancer |
| 404 from the controller | Host/path mismatch, or wrong `pathType` |
| 503 | Backend Service has no endpoints |
| `describe ing` shows `<error: endpoints not found>` | Service name typo, or Service in another namespace |
| TLS not applied | Secret in the wrong namespace, or wrong `secretName` |

🔥 An Ingress can only route to Services in **its own namespace**.

## Lab

1. Deploy an ingress controller. Inspect its Deployment, Service, and IngressClass.
2. Two Deployments + Services. One Ingress routing `/app1` and `/app2` to each.
3. Test with `curl -H "Host: shop.example.com" <ingress-ip>/app1`.
4. Add TLS with a self-signed cert. Test with `curl -k https://...`.
5. **Break/fix:** delete a backend Service. What does `describe ing` show? What HTTP code does the client get?
6. **Break/fix:** set `pathType: Exact` on `/app1` and request `/app1/foo`. Explain the 404.

---
---

# DAY 29 — Gateway API

**New in the v1.35 curriculum. Use gateway-api.sigs.k8s.io — Mumshad's course likely predates this.**

## Why it exists

Ingress overloaded a single object with three concerns and pushed everything non-standard into annotations. Gateway API splits it by **role**:

| Object | Owned by | Purpose |
|---|---|---|
| `GatewayClass` | infrastructure provider | The kind of gateway available (like a StorageClass) |
| `Gateway` | cluster operator | An actual listener — ports, protocols, TLS |
| `HTTPRoute` | application developer | Routing rules pointing at Services |

The chain: **GatewayClass → Gateway → HTTPRoute → Service**

## GatewayClass

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example
spec:
  controllerName: example.net/gateway-controller
```

## Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: prod-gateway
  namespace: infra
spec:
  gatewayClassName: example
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All            # or Same, or Selector
  - name: https
    protocol: HTTPS
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - name: shop-tls
```

`allowedRoutes` is the key difference from Ingress: the Gateway owner controls **which namespaces may attach routes**. That's the role separation.

## HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shop-route
  namespace: apps
spec:
  parentRefs:
  - name: prod-gateway
    namespace: infra
  hostnames:
  - shop.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-svc
      port: 80
      weight: 90
    - name: api-canary
      port: 80
      weight: 10
```

🔥 `parentRefs` points **up** at the Gateway. `backendRefs` points **down** at Services. Multiple `backendRefs` with `weight` gives you traffic splitting — something Ingress cannot do without annotations.

Match types: `path` (`Exact`, `PathPrefix`, `RegularExpression`), `headers`, `queryParams`, `method`.

## Commands

```bash
k get gatewayclass
k get gateway -A
k get httproute -A
k describe gateway prod-gateway -n infra      # 🔥 status conditions say why it isn't Programmed
k describe httproute shop-route -n apps       # 🔥 status says whether it attached to the parent
k api-resources --api-group=gateway.networking.k8s.io
```

🔥 **Read the `status` block.** Gateway API reports success and failure through conditions: `Accepted`, `Programmed`, `ResolvedRefs`. A route that didn't attach says so in its status — there's no separate event to hunt for.

## Ingress vs Gateway API

| | Ingress | Gateway API |
|---|---|---|
| Objects | 1 | 3 |
| Cross-namespace routes | No | Yes, with `allowedRoutes` |
| Traffic splitting | Annotations | Native `weight` |
| Header/method matching | Annotations | Native |
| Protocols | HTTP(S) | HTTP, TCP, UDP, TLS, gRPC |

## Lab

1. `k get crd | grep gateway` — confirm the CRDs are installed.
2. List GatewayClasses. Which controller?
3. Create a Gateway with an HTTP listener on 80, `allowedRoutes.from: All`.
4. Two Services, two HTTPRoutes on different paths, both attached to that Gateway.
5. Check `status` on both the Gateway and the routes.
6. Add weighted `backendRefs` for a 90/10 split.
7. **Break/fix:** set `allowedRoutes.from: Same` and attach a route from another namespace. Where does the failure show up?

---
---

# DAY 30 — NetworkPolicies

**High-frequency exam topic. Get the default-deny pattern automatic.**

## The rules 🔥

1. **Policies are additive.** There is no deny rule — only allow. Multiple policies union together.
2. **A Pod with no policy selecting it accepts everything.**
3. **A Pod selected by any policy denies everything not explicitly allowed** — for the directions listed in `policyTypes`.
4. **If you omit a direction from `policyTypes`, it is not restricted at all.**
5. **Requires a CNI that implements them.** Calico yes, Flannel no. With Flannel, policies apply and silently do nothing.

## Default deny

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: prod
spec:
  podSelector: {}            # empty = every pod in the namespace
  policyTypes:
  - Ingress
  - Egress
```

No `ingress:` or `egress:` blocks = nothing allowed. This is the standard exam starting point.

## Allow specific traffic

```yaml
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api
    - namespaceSelector:
        matchLabels:
          env: prod
    - ipBlock:
        cidr: 10.0.0.0/16
        except:
        - 10.0.5.0/24
    ports:
    - protocol: TCP
      port: 5432
```

## The YAML trap that decides tasks 🔥

```yaml
  # A: two SEPARATE selectors — OR. Pods in ns-a, OR pods labelled app=api anywhere selected
  - from:
    - namespaceSelector: {matchLabels: {name: ns-a}}
    - podSelector: {matchLabels: {app: api}}

  # B: ONE selector with two conditions — AND. Only pods labelled app=api IN ns-a
  - from:
    - namespaceSelector: {matchLabels: {name: ns-a}}
      podSelector: {matchLabels: {app: api}}
```

The difference is a single `-`. Read the task carefully: "from pods labelled X in namespace Y" is form B.

## The DNS trap 🔥🔥

**If you add any egress rule, you must explicitly allow DNS or nothing resolves.**

```yaml
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

This is the single most common NetworkPolicy mistake. The symptom is confusing: the Pod appears healthy, connections to IPs work, and everything by name fails.

Every namespace automatically carries the label `kubernetes.io/metadata.name: <namespace>`, which is the reliable way to select `kube-system`.

## Commands

```bash
k get netpol -A
k describe netpol NAME -n NS
k explain networkpolicy.spec --recursive
```

There is no imperative `k create networkpolicy`. Write the YAML — it's one of the few places you must.

## Testing

```bash
k run test --image=busybox:1.28 --rm -it --restart=Never -- sh
# inside:
wget -O- --timeout=2 http://target-svc:80
nslookup target-svc
```
A **timeout** means blocked by policy. **Connection refused** means it got through and nothing was listening — different problem.

## Lab

1. Three Deployments — `frontend`, `api`, `db` — each with Services. Verify all can reach each other.
2. Apply default-deny to the namespace. Confirm everything breaks.
3. Allow `frontend` → `api` on port 80 only.
4. Allow `api` → `db` on 5432 only. Verify `frontend` still cannot reach `db`.
5. Add an egress policy **without** DNS. Watch name resolution die while IPs still work.
6. Fix it by allowing port 53.
7. Write a policy allowing only Pods labelled `role=admin` **in namespace `ops`** — form B, not form A. Verify a Pod with the right label in the wrong namespace is blocked.

---
---

# DAY 31 — LAB: CNI + Networking Review

**Friday lab. Services & Networking (20%) closes after today.**

## CNI

```bash
ls /etc/cni/net.d/                              # CNI config files
cat /etc/cni/net.d/10-calico.conflist
ls /opt/cni/bin/                                # plugin binaries
k get po -n kube-system -l k8s-app=calico-node
k get no -o jsonpath='{.items[*].spec.podCIDR}' # per-node pod CIDR
```

The kubelet calls the CNI plugin to give each Pod a network namespace and an IP. No CNI = every node stays `NotReady` and no Pod gets an IP.

**CNI comparison:** Calico (NetworkPolicy, BGP), Flannel (simple, **no NetworkPolicy**), Cilium (eBPF), Weave.

## Timed mixed drill — 45 minutes

1. Deployment + ClusterIP + verify from a Pod
2. Convert to NodePort with a specific port
3. Ingress routing two paths to two Services
4. Add TLS to the Ingress
5. Gateway + two HTTPRoutes with a weighted split
6. Default-deny plus three allow policies
7. Write all Service ClusterIPs in a namespace to a file

## Break/fix — the whole domain

**1. DNS blocked by egress policy.** The most important one. Apply an egress policy without port 53. Diagnose from inside a Pod.

**2. Service with no endpoints.** Selector mismatch. Find it with `k get endpoints`.

**3. targetPort wrong.** Endpoints exist, connection refused. Explain the difference from case 2.

**4. Ingress 503.** Backend Service has no endpoints. Trace it.

**5. HTTPRoute won't attach.** `allowedRoutes` restricts namespaces. Find it in the route's `status`.

**6. NetworkPolicy with `-` in the wrong place.** OR when the task wanted AND. Verify by testing from both a matching and a non-matching Pod.

**7. CNI deleted.** Delete the Calico DaemonSet. What happens to running Pods? New ones? Nodes? Restore.

## Exit check

You should be able to state the six-step Service debug order and the NetworkPolicy DNS rule without looking. Both will appear on the exam.

---
---

# DAY 32 — Troubleshooting: Apps, Pods, Debug Toolkit

**Troubleshooting is 30% — the single biggest domain. You have been drilling break/fix every Friday since September; these two days consolidate it.**

## Container states and what each means 🔥

| State | Meaning | First command |
|---|---|---|
| `Pending` | Not scheduled | `k describe po` → FailedScheduling event |
| `ContainerCreating` | Scheduled, still starting | `k describe po` → volume/image events |
| `ImagePullBackOff` / `ErrImagePull` | Image can't be fetched | Check name, tag, registry auth |
| `CrashLoopBackOff` | Starts, then exits repeatedly | `k logs --previous` |
| `OOMKilled` | Exceeded its memory limit | Raise the limit or fix the app |
| `Error` | Exited non-zero, not restarting | `k logs` |
| `CreateContainerConfigError` | Missing ConfigMap/Secret reference | `k describe po` names the object |
| `Init:Error` / `Init:0/2` | Init container failed or waiting | `k logs POD -c INIT_NAME` |
| `Terminating` (stuck) | Finalizer, or a hung preStop hook | `k delete po --force --grace-period=0` |
| `Completed` | Ran and exited 0 | Normal for Jobs |

🔥 `CrashLoopBackOff` vs `CreateContainerConfigError`: the first means the container **started and the app died** — read logs. The second means Kubernetes **couldn't build the container spec** — no logs exist.

## The backoff timer

Restart delay doubles: 10s, 20s, 40s… up to 5 minutes. A Pod with a high restart count and a long gap between attempts has been failing a while. `RESTARTS` plus `AGE` tells you the history.

## Commands

```bash
k get po -o wide                                        # 🔥 phase, restarts, node
k describe po NAME                                      # 🔥 Events, bottom-up
k logs NAME                                             # 🔥
k logs NAME -c CONTAINER                                # multi-container
k logs NAME --previous                                  # 🔥 the crashed instance
k logs NAME --tail=50 --timestamps
k logs -l app=web --all-containers                      # across a whole Deployment
k get events -A --sort-by=.metadata.creationTimestamp   # 🔥
k get events --field-selector type=Warning
k exec -it NAME -- sh
k exec NAME -- env
k exec NAME -- cat /etc/config/key
k exec NAME -- ls -la /path
```

## kubectl debug 🔥

For distroless images with no shell, and for Pods that won't stay up:

```bash
k debug -it POD --image=busybox --target=CONTAINER      # ephemeral container, same namespaces
k debug POD -it --image=busybox --copy-to=debug-pod     # a copy you can modify
k debug POD -it --copy-to=dbg --set-image=app=busybox   # copy with a different image
k debug node/NODE -it --image=busybox                   # host filesystem at /host
```

`--target` shares the process namespace with a specific container so you can inspect its processes.

## Probes — a common cause of "Running but broken"

```yaml
    livenessProbe:      # fails → container RESTARTED
      httpGet: {path: /healthz, port: 8080}
      initialDelaySeconds: 10
      periodSeconds: 5
      failureThreshold: 3
    readinessProbe:     # fails → removed from Service ENDPOINTS, not restarted
      httpGet: {path: /ready, port: 8080}
    startupProbe:       # disables the other two until it passes once
      httpGet: {path: /healthz, port: 8080}
      failureThreshold: 30
```

🔥 A liveness probe with too short an `initialDelaySeconds` on a slow-starting app produces an endless `CrashLoopBackOff` that looks like an application bug. Check probe timings before blaming the code.

🔥 A failing readiness probe drains endpoints — the Pod is `Running` but `0/1 READY` and the Service returns nothing.

## The fixed order 🔥

```text
1. k get po -o wide          → phase, restarts, node
2. k describe po NAME        → Events, bottom-up. 80% of answers are here.
3. k logs NAME [--previous]  → only if the container actually started
4. k get events --sort-by    → cluster-wide context
5. k exec / k debug          → inside the container
6. Check the spec            → image, command, env, volumes, probes, resources
```

**`describe` before `logs`. Always.**

## Lab

Build broken Pods deliberately and diagnose each in under 3 minutes:

1. Nonexistent image tag
2. Private image with no `imagePullSecrets`
3. Command that exits 1 immediately
4. Memory limit of 10Mi on a Pod that allocates more
5. Reference to a missing ConfigMap key
6. Init container that never succeeds
7. Liveness probe on the wrong port
8. Readiness probe that always fails — note the Pod stays `Running` but endpoints are empty
9. Resource requests larger than any node
10. A Pod stuck `Terminating` due to a finalizer

For each: name the state, the failed stage, and the command that revealed it.

---
---

# DAY 33 — Troubleshooting: Nodes, kubelet, Control Plane

**Where most candidates lose points. Formulaic once practised.**

## Node NotReady

```bash
k get no                                        # 🔥
k describe no NODE                              # 🔥 Conditions section
```

| Condition | Meaning |
|---|---|
| `Ready: False` | kubelet not reporting |
| `MemoryPressure: True` | Low memory — eviction begins |
| `DiskPressure: True` | Low disk — image GC, then eviction |
| `PIDPressure: True` | Too many processes |
| `NetworkUnavailable: True` | CNI not configured |

**SSH to the node:**
```bash
systemctl status kubelet                        # 🔥
journalctl -u kubelet -f                        # 🔥
journalctl -u kubelet --since "10 min ago" --no-pager
systemctl restart kubelet
systemctl enable kubelet
```

**Common kubelet failures:**

| Cause | Evidence |
|---|---|
| Swap enabled | kubelet refuses to start; explicit log message |
| containerd down | `systemctl status containerd` |
| Cgroup driver mismatch | Pods crashloop; check `SystemdCgroup = true` |
| Expired certs | `kubeadm certs check-expiration` |
| Wrong API server address | `/etc/kubernetes/kubelet.conf` |
| Disk full | `df -h` |

**Config locations:**
```bash
/var/lib/kubelet/config.yaml       # kubelet configuration
/etc/kubernetes/kubelet.conf       # kubeconfig for the kubelet
/etc/kubernetes/pki/               # certificates
/etc/kubernetes/manifests/         # static pods
```

## Control plane down 🔥

When `kubectl` itself fails, you have no API. Work on the filesystem and with `crictl`.

```bash
crictl ps -a                                    # 🔥 including exited containers
crictl logs <container-id>                      # 🔥 why the apiserver died
crictl pods
```

**The workflow:**

```bash
# 1. Confirm the manifest is valid
cat /etc/kubernetes/manifests/kube-apiserver.yaml

# 2. Find the exited container and read its logs
crictl ps -a | grep apiserver
crictl logs <id>

# 3. Fix the manifest — kubelet restarts it automatically
vim /etc/kubernetes/manifests/kube-apiserver.yaml

# 4. Watch it come back
watch crictl ps
k get po -n kube-system
```

🔥 **You never run `systemctl restart kube-apiserver`.** It isn't a service. Editing the manifest is the restart mechanism.

**Common control plane breakages:**

| Cause | Symptom |
|---|---|
| Typo in a manifest flag | apiserver container exits immediately |
| Wrong `--etcd-servers` | apiserver starts, can't reach etcd |
| Bad cert path in a manifest | container exits, `crictl logs` names the file |
| Wrong port | `kubectl` connection refused |
| etcd data dir wrong | etcd exits; everything else follows |
| Manifest moved out of the directory | Pod disappears entirely |

🔥 A useful trick: if a manifest is malformed YAML, the kubelet logs the parse error but the Pod never appears in `crictl ps` at all. `journalctl -u kubelet` is where you find it.

## Scheduler and controller-manager down

Both are static Pods. If the **scheduler** is down, new Pods stay `Pending` forever with no events — existing Pods are unaffected. Workaround for a single Pod: set `nodeName` directly.

If **controller-manager** is down, Deployments don't create ReplicaSets, nodes never get marked NotReady, and endpoints stop updating.

## Lab

1. Stop the kubelet on a worker. Time how long until `NotReady`. When are Pods evicted?
2. Enable swap and restart the kubelet. Read the exact refusal message.
3. Break `kube-apiserver.yaml` three ways — bad flag, bad cert path, bad port. Recover each using only `crictl` and vim.
4. Move `kube-scheduler.yaml` out of the manifests directory. What breaks? Schedule a Pod anyway.
5. Break `SystemdCgroup`. Diagnose from Pod symptoms back to containerd config.
6. Fill a node's disk. Watch `DiskPressure` and eviction.
7. **Timed:** have someone break something you don't know about, and fix it in 10 minutes.

---
---

# DAY 34 — MOCK EXAM #1 (killer.sh)

**2 hours. Exam conditions. No pausing.**

## Rules

- killer.sh session 1 — free with your exam registration, 36 hours of access once started
- Only kubernetes.io/docs, the Kubernetes blog, and Kubernetes GitHub
- No notes, no this file, no scrolling back
- Set a timer and do not stop it

## Strategy

1. **First 5 minutes:** read every question, note the weight, pick your order. Do high-weight, high-confidence tasks first.
2. **Every question:** set your context first — `k config use-context <name>`.
3. **Read the namespace.** Use `-n` explicitly.
4. **Anything over ~6 minutes:** flag it, skip it, come back.
5. **Partial credit counts.** A half-done 8% task beats a perfect 2% one.
6. **Do not read solutions** until the full 2 hours have elapsed.

## Expect a low score

killer.sh is deliberately harder than the real exam — more questions, tighter time. A score in the 40s–50s here is normal and is not a prediction of failure.

## Record

- Total score and score per question
- Time per question
- Every task you got stuck on
- Every command you had to look up

That list is Day 35's agenda.

---
---

# DAY 35 — Mock #1 Review + Weak Areas

**The highest-value session of the month. A mock you don't review is a mock you wasted.**

## Process

1. **Work through every missed answer.** Understand the intended approach, not just the commands.
2. **Redo each failed task from scratch, timed.** Reading a solution does not build recall — reproducing it does.
3. **Pull out your weak-topic list from Day 22.** Drill anything still shaky.
4. **Categorise every mistake:**

| Category | Fix |
|---|---|
| Didn't know the concept | Re-read that day's notes, redo that lab |
| Knew it, too slow | Drill the command until it's automatic |
| Knew it, wrong namespace/context | Process problem — build the `-n` habit |
| Misread the question | Slow down on the read; the exam rewards it |
| Ran out of time | Practise flagging and skipping |

That fourth column matters. A "too slow" problem and a "didn't know" problem need completely different remedies, and treating them the same wastes the day.

## Re-drill regardless of your score

- etcd backup + restore
- A full node upgrade
- One RBAC task, verified with `auth can-i`
- One NetworkPolicy with correct DNS egress
- One Service debugged through the six-step order

Write down your three biggest remaining gaps for tomorrow.

---
---

# DAY 36 — MOCK EXAM #2 (killer.sh)

**2 hours. Your dress rehearsal.**

Same rules as Day 34. killer.sh session 2.

## What's different this time

🔥 **Track time per question.** Pacing is what the exam actually tests. Write down the clock at the start and end of each task.

Afterwards, compare against Mock #1:
- Which topics improved?
- Which are still slow?
- Did you flag and skip effectively, or sink time into one task?
- Did you set the context every time?

## If Mock #1 went badly

Consider moving this to Day 37 and skipping the light review. A second real diagnostic is worth more than a calm final day. That's your call — but decide deliberately, not by drifting.

---
---

# DAY 37 — Mock #2 Review + Final Check

**Day before the exam. No new material. Confidence, not cramming.**

## Do

1. Review every missed task from Mock #2. Redo each once.
2. Re-run etcd backup + restore one final time from memory.
3. Skim your docs bookmarks — confirm you can find each page in under 20 seconds.
4. Confirm muscle memory: `alias k`, `$do`, `$now`, vim `expandtab`.
5. Check logistics: ID, clean workspace, browser, network, exam start time.

## Do not

- Learn anything new
- Take a third mock
- Study past your two hours

**Stop early. Sleep matters more than one more lab.**

## The 🔥 checklist

Go through every 🔥 item in this file. Anything you can't produce from memory, drill this morning. Anything you can, leave alone.

Highest-value items to confirm:
- The five-stage chain and its symptom→stage mapping
- `$do` and `$now`
- `k create deploy/cm/secret/job/cj/sa/role/rolebinding/quota/ingress`
- `k expose`, `k set image`, `k rollout undo --to-revision`
- Drain flags: `--ignore-daemonsets --delete-emptydir-data`
- Upgrade order: kubeadm binary → apply → drain → kubelet → restart → uncordon
- etcd backup and the **two-step** restore
- `k auth can-i --as=`
- The six-step Service debug order
- NetworkPolicy DNS egress on port 53
- `describe` before `logs`

---
---

# EXAM DAY — Tuesday 27 October 2026

## Format

- 2 hours, performance-based, ~15–20 tasks on live clusters
- **66/100 to pass**, partial credit per task
- One free retake included
- Each question SSHes to a different node — your `export` lines die on every hop

## Allowed

kubernetes.io/docs · kubernetes.io/blog · github.com/kubernetes
Copy-pasting **from** the docs into the terminal is allowed and expected.
Copy-paste inside the terminal: `Ctrl+Shift+C` / `Ctrl+Shift+V`.

## First 60 seconds of every question

```bash
k config use-context <name>              # 🔥 ALWAYS FIRST
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
```
Then read the task twice, note the namespace, and note the weight.

## Rules for yourself

1. Set the context. Every time.
2. Read the namespace. Use `-n` explicitly.
3. Generate, then edit. Never write YAML from empty.
4. Verify what you built — `k get`, `k exec`, `k auth can-i`.
5. Over 6 minutes? Flag, skip, return.
6. Partial credit is real. Bank the easy points.
7. Don't fight one task at the cost of three others.

## If something goes wrong

- A cluster looks broken → check whether that *is* the question
- `kubectl` doesn't respond → check the context first, then the API server
- You break something → note it and move on; each question is a separate cluster

**66 out of 100. You can get a third of it wrong. Breathe.**
