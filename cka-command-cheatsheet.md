# CKA Command Cheat Sheet

Every command assumes `alias k=kubectl`. Add `-n <namespace>` to almost everything.

**Exam weighting:** Troubleshooting 30% · Cluster Architecture 25% · Services & Networking 20% · Workloads & Scheduling 15% · Storage 10%

🔥 = memorise, you will type this under time pressure
📖 = look it up in the docs, not worth memorising

---

## 1. Terminal Setup

Run these at the start of every exam question. The `k` alias and completion are pre-configured on the exam terminal; the two exports are not.

| Command | What it does |
|---|---|
| `alias k=kubectl` | Saves 4 keystrokes per command |
| `complete -o default -F __start_kubectl k` | Makes tab-completion work with the alias |
| 🔥 `export do='--dry-run=client -o yaml'` | Generates YAML instead of creating the object |
| 🔥 `export now='--force --grace-period=0'` | Deletes instantly instead of waiting 30s |

`~/.vimrc` — without `expandtab`, vim inserts tab characters and **YAML rejects tabs**:

```
set expandtab
set tabstop=2
set shiftwidth=2
set number
```

**Each exam question SSHes to a different node.** Your exports die on every hop. Retype them, or paste from a file you created inside the exam environment (Ctrl+Shift+V works in the terminal).

---

## 2. Core Mechanics

### Getting information

| Command | When to use it |
|---|---|
| 🔥 `k get po -o wide` | Always. Node + IP for the same keystrokes |
| `k get po -A` | Find something when you don't know its namespace |
| `k get po --show-labels` | Before writing any selector |
| `k get po -l app=web` | Filter by label |
| `k get po -l 'env in (dev,prod)'` | Set-based selector |
| `k get po -l 'env!=prod'` | Negative selector |
| `k get deploy,rs,po` | Whole ownership chain in one round trip |
| `k get all` | Pods, Deployments, RS, SVC, Jobs. **Not** ConfigMaps, Secrets, PVCs, Ingress, SA |
| 🔥 `k get po --sort-by=.metadata.creationTimestamp` | Newest last |
| `k get po -w` | Watch mode — run in a second terminal during rollouts |
| `k get po <name> -o yaml` | See what the API server actually stored |

### Describing and explaining

| Command | When to use it |
|---|---|
| 🔥 `k describe po <name>` | Second step of every Pod problem. Read **Events** bottom-up |
| 🔥 `k explain pod.spec.containers` | Field lookup, offline, always version-correct |
| 🔥 `k explain pod.spec.volumes --recursive` | Full subtree with exact nesting — use when you need indentation |
| `k api-resources` | Every kind, its short name, apiVersion, namespaced or not |
| `k api-resources --namespaced=false` | Cluster-scoped resources (nodes, PV, StorageClass, ClusterRole, ns) |
| `k api-versions` | Every available API group/version |

### Events

| Command | When to use it |
|---|---|
| 🔥 `k get events --sort-by=.metadata.creationTimestamp` | Always sort. Unsorted output is chaos |
| `k get events -A --field-selector type=Warning` | Cluster-wide problems only |
| `k events --for pod/<name>` | Events for one object (newer syntax) |

### API versions worth memorising

| Kind | apiVersion |
|---|---|
| Pod, Service, ConfigMap, Secret, Namespace, PV, PVC, ServiceAccount | `v1` |
| Deployment, ReplicaSet, DaemonSet, StatefulSet | `apps/v1` |
| Job, CronJob | `batch/v1` |
| Role, RoleBinding, ClusterRole, ClusterRoleBinding | `rbac.authorization.k8s.io/v1` |
| NetworkPolicy | `networking.k8s.io/v1` |
| Ingress, IngressClass | `networking.k8s.io/v1` |
| StorageClass | `storage.k8s.io/v1` |
| HorizontalPodAutoscaler | `autoscaling/v2` |

---

## 3. Creating Things Imperatively

**The split: `k run` makes Pods. `k create` makes everything else.**

Add `$do` to any of these to get YAML instead of a live object.

### Pods

| Command | Notes |
|---|---|
| 🔥 `k run web --image=nginx` | The only imperative way to make a Pod |
| `k run web --image=nginx --port=80` | Adds containerPort |
| `k run web --image=nginx --labels="app=web,tier=fe"` | |
| `k run web --image=nginx --env=KEY=value` | |
| `k run web --image=nginx --restart=Never` | Bare Pod, unmanaged |
| `k run web --image=nginx --command -- sleep 3600` | Override entrypoint |
| 🔥 `k run tmp --image=busybox --rm -it -- sh` | Throwaway debug shell. You'll live in this for DNS work |
| `k run web --image=nginx $do > pod.yaml` | Generate, then edit |

### Everything else

| Command | Notes |
|---|---|
| 🔥 `k create deploy web --image=nginx --replicas=3` | |
| 🔥 `k create ns dev` | |
| 🔥 `k create cm app --from-literal=K=V` | Repeat the flag for more keys |
| 🔥 `k create secret generic db --from-literal=pass=x` | |
| `k create job pi --image=perl -- perl -e 'print 1'` | |
| `k create cj report --image=busybox --schedule="*/5 * * * *" -- date` | |
| `k create sa build-bot` | |
| `k create role dev --verb=get,list --resource=pods` | |
| `k create rolebinding rb --role=dev --serviceaccount=default:build-bot` | |
| `k create quota q --hard=cpu=2,memory=2Gi` | |
| 🔥 `k expose deploy web --port=80 --target-port=8080` | Inherits the selector automatically |

### Editing and replacing

| Command | When to use it |
|---|---|
| `k edit deploy web` | Mutable fields only |
| `k patch deploy web -p '{"spec":{"replicas":5}}'` | Scripted single-field change |
| 🔥 `k replace --force -f pod.yaml` | Delete + recreate. **The move for immutable fields** |
| `k apply -f file.yaml` | Declarative create-or-update |
| `k delete po web $now` | Instant delete |

---

## 4. Workloads & Scheduling (15%)

### Deployments and rollouts

| Command | Notes |
|---|---|
| 🔥 `k scale deploy web --replicas=5` | |
| 🔥 `k set image deploy/web nginx=nginx:1.25` | Syntax is `CONTAINER=IMAGE`, not deployment name |
| 🔥 `k rollout status deploy/web` | Blocks until done or failed |
| 🔥 `k rollout history deploy/web` | |
| `k rollout history deploy/web --revision=2` | Inspect before rolling back |
| 🔥 `k rollout undo deploy/web` | Back one revision |
| 🔥 `k rollout undo deploy/web --to-revision=1` | To a specific revision |
| `k rollout pause deploy/web` / `resume` | Batch several edits into one rollout |
| `k rollout restart deploy/web` | Recreates Pods with the **same** template — how you pick up a changed ConfigMap |
| 🔥 `k annotate deploy/web kubernetes.io/change-cause="..."` | `--record` is deprecated; CHANGE-CAUSE is empty without this |

**Reading `k get deploy`:** READY = passing readiness · UP-TO-DATE = on current template · AVAILABLE = ready long enough to count. `3/3 1 3` = rollout stuck. `0/3 3 0` = app failing readiness.

**Pod name decoding:** `web-6b7f9c8d4-2xk9p` = deployment + template-hash (the ReplicaSet identity) + instance.

### Labels, taints, tolerations

| Command | Notes |
|---|---|
| `k label po web env=prod` | |
| `k label po web env-` | Trailing dash removes |
| `k label po web env=dev --overwrite` | |
| 🔥 `k taint node node1 key=value:NoSchedule` | |
| 🔥 `k taint node node1 key=value:NoSchedule-` | Trailing dash removes |
| `k describe node node1 \| grep -i taint` | |

**Taint effects:** `NoSchedule` (no new Pods) · `PreferNoSchedule` (soft) · `NoExecute` (evicts existing Pods too).

**Tolerations are permission, not attraction.** A toleration lets a Pod land on a tainted node; it does not push it there. Use nodeAffinity or nodeSelector to attract.

📖 nodeAffinity, podAffinity, topologySpreadConstraints — generate with `k explain` and copy from docs.

### Jobs and CronJobs

| Field | Meaning |
|---|---|
| `completions` | How many successful runs are needed |
| `parallelism` | How many run at once |
| `backoffLimit` | Retries before marking Failed (default 6) |
| `activeDeadlineSeconds` | Hard timeout |
| `restartPolicy` | Must be `OnFailure` or `Never` for Jobs |
| `schedule` | Cron syntax: `min hour day month weekday` |
| `concurrencyPolicy` | `Allow` / `Forbid` / `Replace` |
| `suspend: true` | Pause a CronJob without deleting it |

### Resources and QoS

| Command | Notes |
|---|---|
| `k top nodes` / `k top pods` | Needs metrics-server |
| `k create quota q --hard=cpu=2,memory=2Gi,pods=10` | |
| `k describe ns dev` | Shows quotas and limit ranges |

**QoS classes:** `Guaranteed` (requests == limits for all containers) · `Burstable` (requests set, less than limits) · `BestEffort` (nothing set). BestEffort is evicted first under pressure.

### Static Pods

Not created with kubectl — drop a YAML file in the manifest directory and the kubelet picks it up.

```bash
ls /etc/kubernetes/manifests/          # where the control plane lives
grep staticPodPath /var/lib/kubelet/config.yaml
```

Static Pods get the node name appended: `mypod-node01`. You cannot delete them with `kubectl` — remove the file.

---

## 5. ConfigMaps & Secrets

### Creating

| Command | Result |
|---|---|
| `k create cm app --from-literal=K=V` | One key per flag |
| `k create cm app --from-file=app.conf` | **Filename becomes the key, whole file becomes the value** |
| `k create cm app --from-file=mykey=app.conf` | You choose the key |
| `k create cm app --from-file=./dir/` | One key per file in the directory |
| `k create cm app --from-env-file=app.env` | **One key per line** |
| `k create secret generic db --from-literal=pass=x` | |
| `k create secret tls web --cert=tls.crt --key=tls.key` | Creates keys `tls.crt` and `tls.key` |
| `k create secret docker-registry reg --docker-server=... --docker-username=... --docker-password=...` | For private image pulls |

`--from-file` vs `--from-env-file` on the same file give completely different results. Read the task carefully.

### Updating an existing one

```bash
k create cm app --from-literal=K=newval $do | k replace -f -
```

`k create` alone errors if the object exists.

### Consuming

| Purpose | ConfigMap | Secret |
|---|---|---|
| Single key as env var | `configMapKeyRef` | `secretKeyRef` |
| All keys as env vars | `envFrom: configMapRef` | `envFrom: secretRef` |
| As a volume | `configMap: {name: x}` | `secret: {secretName: x}` |

Note the volume field differs: `name` vs `secretName`.

### base64

```bash
k get secret db -o jsonpath='{.data.pass}' | base64 -d
echo -n 'mypass' | base64          # -n matters! trailing newline breaks auth
```

`stringData:` in a manifest lets you write plain text — it's write-only and appears as `data` when you read it back.

### Update behaviour 🔥

- **Volume-mounted** ConfigMaps/Secrets update in running Pods (~60s kubelet sync)
- **Env vars never update.** Set at container start, permanently
- **`subPath` mounts never update** either
- Fix: `k rollout restart deploy/web`

Mounting a volume over a directory **hides everything already there**. Mount over `/etc` and the container breaks.

---

## 6. Services & Networking (20%)

### Services

| Command | Notes |
|---|---|
| 🔥 `k expose deploy web --port=80 --target-port=8080` | ClusterIP, selector inherited |
| `k expose deploy web --port=80 --type=NodePort` | |
| `k expose po web --port=80 --name=web-svc` | |
| 🔥 `k get ep` / `k get endpointslices` | **Your #1 Service debugging tool** |
| `k get svc -o wide` | Shows the selector |

**Port terminology:** `port` = the Service's port · `targetPort` = the container's port · `nodePort` = port on every node (30000–32767).

**Types:** `ClusterIP` (internal, default) · `NodePort` (adds a port on every node) · `LoadBalancer` (adds an external LB) · `ExternalName` (CNAME, no proxying) · headless (`clusterIP: None`, DNS returns Pod IPs directly).

🔥 **Empty endpoints means the selector doesn't match any Pod labels.** That's the most common broken-Service cause.

### DNS

| Command | Notes |
|---|---|
| 🔥 `k run tmp --image=busybox --rm -it -- sh` | Then `nslookup` / `wget -O-` from inside |
| `k get po -n kube-system -l k8s-app=kube-dns` | CoreDNS pods |
| `k get cm coredns -n kube-system -o yaml` | The Corefile |
| `k exec <pod> -- cat /etc/resolv.conf` | |

**FQDN format:** `<service>.<namespace>.svc.cluster.local`
**Pod DNS:** `<pod-ip-with-dashes>.<namespace>.pod.cluster.local`

### Ingress

| Command | Notes |
|---|---|
| `k create ing web --rule="host/path=svc:80"` | Imperative creation |
| `k get ing` | |
| `k describe ing web` | |
| `k get ingressclass` | |

`pathType` must be `Prefix`, `Exact`, or `ImplementationSpecific`. An Ingress with no controller running does absolutely nothing.

### Gateway API 📖

New in the curriculum. The chain: **GatewayClass → Gateway → HTTPRoute → Service**.

```bash
k get gatewayclass
k get gateway
k get httproute
k describe httproute <name>
```

Key fields: Gateway has `listeners` (name, port, protocol, allowedRoutes). HTTPRoute has `parentRefs` (which Gateway), `rules.matches`, `rules.backendRefs`.

### NetworkPolicy

| Command | Notes |
|---|---|
| `k get netpol` | |
| `k describe netpol <name>` | |

🔥 Critical rules:
- Policies are **additive**. There is no deny rule, only allow
- An empty `podSelector: {}` selects **every** Pod in the namespace
- If you omit a `policyType`, that direction is **not restricted**
- **Adding egress rules breaks DNS** unless you explicitly allow UDP+TCP port 53
- `namespaceSelector` needs the target namespace to actually carry that label

### CNI

```bash
ls /etc/cni/net.d/
k get po -n kube-system            # CNI pods (calico, flannel, etc.)
```

Flannel does **not** implement NetworkPolicy. Use Calico for practice.

---

## 7. Storage (10%)

| Command | Notes |
|---|---|
| `k get pv` | Cluster-scoped — no namespace |
| `k get pvc -n dev` | Namespaced |
| `k get sc` | StorageClasses, cluster-scoped |
| `k describe pvc <name>` | Says why it's Pending |

**accessModes:** `ReadWriteOnce` (RWO, one node) · `ReadOnlyMany` (ROX) · `ReadWriteMany` (RWX) · `ReadWriteOncePod` (RWOP, one Pod).

**reclaimPolicy:** `Retain` (keep data after PVC deletion) · `Delete` (destroy it).

**volumeBindingMode:** `Immediate` · `WaitForFirstConsumer` (waits for a Pod, so the scheduler can pick a suitable node).

🔥 **PVC stuck Pending** — check in this order:
1. Is there a PV with matching `capacity`, `accessModes`, **and** `storageClassName`?
2. Is there a default StorageClass? (`k get sc` — look for `(default)`)
3. Is `volumeBindingMode: WaitForFirstConsumer`? Then it waits for a Pod on purpose.

---

## 8. Cluster Architecture (25%)

### kubeadm

| Command | Notes |
|---|---|
| `kubeadm init --pod-network-cidr=192.168.0.0/16` | Bootstrap control plane |
| `kubeadm token create --print-join-command` | Regenerate a lost join command |
| `kubeadm join <ip>:6443 --token=... --discovery-token-ca-cert-hash=...` | |
| `kubeadm reset` | Undo init/join |
| `kubeadm certs check-expiration` | |

### Upgrades 🔥

Order matters. Control plane first, then workers, one at a time. **Never skip a minor version.**

```bash
# Control plane
apt-mark unhold kubeadm && apt-get install -y kubeadm=1.36.x-* && apt-mark hold kubeadm
kubeadm upgrade plan
kubeadm upgrade apply v1.36.x
k drain <cp-node> --ignore-daemonsets
apt-mark unhold kubelet kubectl && apt-get install -y kubelet=1.36.x-* kubectl=1.36.x-* && apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
k uncordon <cp-node>

# Each worker
k drain <node> --ignore-daemonsets --delete-emptydir-data
# (on the worker) upgrade kubeadm, then:
kubeadm upgrade node
# upgrade kubelet + kubectl, restart kubelet
k uncordon <node>
```

### Node lifecycle

| Command | Notes |
|---|---|
| 🔥 `k drain <node> --ignore-daemonsets --delete-emptydir-data` | `--force` also removes bare Pods |
| `k cordon <node>` | Mark unschedulable, don't evict |
| 🔥 `k uncordon <node>` | The step people forget |
| `k delete node <node>` | Remove from the cluster |

### etcd backup and restore 🔥

Get the cert paths from `/etc/kubernetes/manifests/etcd.yaml` first.

```bash
ETCDCTL_API=3 etcdctl snapshot save /opt/backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

ETCDCTL_API=3 etcdctl snapshot status /opt/backup.db --write-out=table

ETCDCTL_API=3 etcdctl snapshot restore /opt/backup.db \
  --data-dir=/var/lib/etcd-restore
```

🔥 **Restore is two steps.** After `snapshot restore` to a **new empty directory**, you must edit `/etc/kubernetes/manifests/etcd.yaml` and point the `hostPath` volume at the new data dir. The kubelet restarts etcd automatically. Forgetting this second step is the single most common etcd task failure.

### RBAC

| Command | Notes |
|---|---|
| `k create role dev --verb=get,list,watch --resource=pods -n dev` | |
| `k create clusterrole admin-r --verb=* --resource=*` | |
| `k create rolebinding rb --role=dev --user=jane -n dev` | |
| `k create rolebinding rb --role=dev --serviceaccount=dev:bot -n dev` | |
| `k create clusterrolebinding crb --clusterrole=view --user=jane` | |
| 🔥 `k auth can-i get pods --as=jane -n dev` | **Verify every RBAC task with this** |
| `k auth can-i --list --as=jane -n dev` | Everything a subject can do |

A **ClusterRole bound by a RoleBinding** grants those permissions in one namespace only. That distinction is heavily tested.

The core API group is `""` (empty string) — pods, services, configmaps, secrets.

### ServiceAccounts and certificates

| Command | Notes |
|---|---|
| `k create sa bot` | |
| `k create token bot` | Short-lived token |
| `k get csr` | |
| `k certificate approve <name>` | |
| `k certificate deny <name>` | |
| `k get csr <name> -o jsonpath='{.status.certificate}' \| base64 -d` | Extract the signed cert |

A Pod's ServiceAccount **cannot be changed after creation**.

### kubeconfig

| Command | Notes |
|---|---|
| `k config view` | |
| `k config view --minify` | Current context only |
| `k config get-contexts` | |
| 🔥 `k config use-context <name>` | **First command of every exam question** |
| `k config current-context` | |
| `k config set-context --current --namespace=dev` | |
| `k config view --minify \| grep namespace` | Verify it took |

### Helm 📖

| Command | Notes |
|---|---|
| `helm repo add <name> <url>` / `helm repo update` | |
| `helm search repo <term>` | |
| `helm install <release> <chart>` | |
| `helm install <release> <chart> --set key=value` | |
| `helm install <release> <chart> -f values.yaml` | |
| `helm upgrade <release> <chart>` | |
| `helm rollback <release> <revision>` | |
| `helm list -A` | |
| `helm get values <release>` | What a release was configured with |
| `helm template <chart>` | Preview manifests without installing |
| `helm uninstall <release>` | |

### Kustomize 📖

| Command | Notes |
|---|---|
| `k apply -k ./overlays/prod` | |
| `k kustomize ./overlays/prod` | Preview without applying |

`kustomization.yaml` keys: `resources`, `namePrefix`, `nameSuffix`, `commonLabels`, `namespace`, `patches`, `configMapGenerator`, `secretGenerator`.

### CRDs and Operators 📖

```bash
k get crd
k api-resources | grep <group>
k explain <customkind>
k get <customkind> -A
```

An orphaned custom resource with a finalizer is a classic cause of a namespace stuck in `Terminating`.

---

## 9. Troubleshooting (30%)

### The five-stage chain 🔥

```
kubectl → apiserver → etcd → scheduler → kubelet → runtime
   1          2         2        3          4         4
```

| Symptom | Failed stage | Where to look |
|---|---|---|
| `kubectl` won't connect | 1 | apiserver static pod manifest |
| Pod `Pending` | 3 | Scheduler — resources, taints, affinity, PVC |
| Pod has node, not Running | 4 | kubelet, runtime, image |
| Pod Running but broken | — | Application, config, networking |

### Fixed debugging order 🔥

```bash
k get po -o wide                 # 1. phase? node?
k describe po <name>             # 2. Events, read bottom-up
k logs <name>                    # 3. app output
k logs <name> --previous         # 4. if it already crashed
k logs <name> -c <container>     # 5. multi-container pods
k get events --sort-by=.metadata.creationTimestamp
k exec -it <name> -- sh          # 6. inside: mounts, env, connectivity
```

**`describe` before `logs`, always.** If the container never started, there are no logs.

### Container states

| Reason | Meaning | First thing to check |
|---|---|---|
| `ImagePullBackOff` / `ErrImagePull` | Can't fetch image | Image name, tag, registry secret |
| `CrashLoopBackOff` | Starts then exits repeatedly | `logs --previous` |
| `Pending` | Not scheduled | `describe` → FailedScheduling event |
| `OOMKilled` | Exceeded memory limit | Raise limits or fix the app |
| `CreateContainerConfigError` | Missing ConfigMap/Secret reference | `describe` names the missing object |
| `Init:Error` / `Init:CrashLoopBackOff` | Init container failing | `logs <pod> -c <init-container>` |
| `ContainerCreating` (stuck) | Volume or CNI problem | `describe`, then kubelet logs |

### Debug tools

| Command | Notes |
|---|---|
| `k debug -it <pod> --image=busybox --target=<container>` | Ephemeral container in a running Pod |
| `k debug node/<node> -it --image=ubuntu` | Shell onto a node |
| `k debug <pod> --copy-to=debug-pod --image=busybox` | Copy with modifications |
| `k exec -it <pod> -- sh` | |
| `k cp <pod>:/path/file ./file` | |
| `k port-forward pod/<name> 8080:80` | Test a Pod directly, bypassing Services |

### Node-level (SSH to the node)

| Command | Notes |
|---|---|
| 🔥 `systemctl status kubelet` | |
| 🔥 `journalctl -u kubelet -f` | Add `--since "10 min ago"` |
| `systemctl restart kubelet` | |
| `systemctl status containerd` | |
| 🔥 `crictl ps -a` | Containers, when kubectl is down |
| 🔥 `crictl logs <container-id>` | |
| `crictl pods` | |
| `cat /var/lib/kubelet/config.yaml` | kubelet config |
| `cat /etc/kubernetes/kubelet.conf` | kubelet's kubeconfig |
| `ls /etc/kubernetes/manifests/` | Static pod manifests |

### Control plane down 🔥

The control plane runs as static pods. **You fix it by editing a file**, and the kubelet restarts it automatically — no `systemctl` needed.

```bash
ls /etc/kubernetes/manifests/
# apiserver.yaml, etcd.yaml, kube-controller-manager.yaml, kube-scheduler.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
crictl ps -a | grep apiserver     # watch it come back
journalctl -u kubelet | tail -50  # kubelet logs why it won't start
```

Common breaks: wrong `--etcd-servers`, bad cert path, wrong port, YAML syntax error.

### Service not working — fixed order

```
1. Does the Service exist?          k get svc -n NS
2. Does it have endpoints?          k get ep <svc> -n NS      ← empty = selector mismatch
3. Do the Pods work directly?       k port-forward pod/<name> 8080:80
4. Does DNS resolve?                nslookup from a busybox pod
5. Is kube-proxy running?           k get po -n kube-system | grep proxy
6. Is a NetworkPolicy blocking it?  k get netpol -n NS
```

---

## 10. Output Formats & JSONPath

| Command | Result |
|---|---|
| `k get po -o wide` | Extra columns |
| `k get po -o yaml` / `-o json` | Full object |
| `k get po -o name` | `pod/nginx` format |
| `k get po --no-headers` | Strip the header row |

### JSONPath patterns

```bash
# Space-separated on one line
k get po -o jsonpath='{.items[*].metadata.name}'

# One per line
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# All images
k get po -o jsonpath='{.items[*].spec.containers[*].image}'

# Filter by field
k get no -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# One field from one object
k get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### custom-columns — usually easier under pressure

```bash
k get po -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image
```

### Writing answers to files

Exam tasks often say "write the result to /opt/answer.txt". **Read the required format carefully** — space-separated and newline-separated are different answers.

```bash
k get po -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > /opt/answer.txt
```

---

## 11. Exam-Day Workflow

**Every question:**

1. `k config use-context <given-context>` — first, always
2. Read the task twice. Note the **namespace** and the **weight**
3. Retype your two exports if you SSHed to a new node
4. Solve it
5. Verify — `k get`, `k describe`, or `k auth can-i`
6. Over ~6 minutes? Flag it, move on, come back

**Facts:**
- Passing score is 66/100
- Partial credit exists — a half-finished 8% task beats a perfect 2% task
- kubernetes.io/docs, the Kubernetes blog, and Kubernetes GitHub are open
- Copy-paste from the docs into the terminal is allowed and expected
- You get one free retake

**Highest-value things to have automatic:**
1. `$do` generate-then-edit
2. `-n` on every command
3. etcd backup + restore including the manifest edit
4. `k auth can-i` after every RBAC task
5. `k get ep` as the first move on any Service problem
6. `describe` → Events, bottom-up

---

## 12. Fast Cleanup

```bash
k delete ns <name>              # removes everything inside — never on exam day unless asked
k delete po --all -n <ns>
k delete deploy,svc,cm --all -n <ns>
k delete po <name> --force --grace-period=0
```
