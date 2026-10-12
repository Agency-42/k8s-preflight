# k8s-preflight

A small, read-only Bash script that checks a Kubernetes cluster before a minor version upgrade (for example 1.34 → 1.35). It asks the API server the questions you should ask before a maintenance window, and tells you which answers will hurt.

Think of it as the walk-around before take-off. It doesn't fly the plane.

## What it checks

| # | Check | How |
|---|---|---|
| 1 | Upgrade path and kubectl/server version skew | `kubectl version`; flags skipped minors and kubectl outside ±1 |
| 2 | Nodes: kubelet skew, readiness, container runtime, kernel | `.status.nodeInfo`; kubelet newer than the API server, more than 3 minors behind the target, containerd 1.x, kernel < 5.8 (cgroup v2 hint), `kubelet_cri_losing_support` on the node metrics |
| 3 | Deprecated / removed API usage | `apiserver_requested_deprecated_apis` from `kubectl get --raw /metrics`; FAIL if the removal release is ≤ the target |
| 4 | etcd health | `/readyz/etcd` through the API server; etcd image version if it runs as a static pod (warns on 3.5 < 3.5.26) |
| 5 | PodDisruptionBudgets that block drains | PDBs with `disruptionsAllowed: 0` |
| 6 | Pending and crash-looping pods | field selectors and container states |
| 7 | Certificate expiry hints | API server serving certificate via `openssl s_client`; reminder for `kubeadm certs check-expiration` |
| 8 | Add-ons worth a look | retired community Ingress NGINX, kube-proxy in ipvs mode |

It never changes anything in the cluster. Everything is a `get`.

## Requirements

- `bash` 4+, `kubectl`, `awk`, `sed`, `grep`
- `openssl` (optional, for the certificate check)
- Read access to nodes, pods, PDBs, `kube-system` ConfigMaps and the `/metrics`, `/readyz` non-resource URLs. A cluster-admin or a read-only "view + metrics" role works.

## Usage

```bash
curl -LO https://raw.githubusercontent.com/Agency-42/k8s-preflight/main/k8s-preflight
chmod +x k8s-preflight

./k8s-preflight                    # target = current server minor + 1
./k8s-preflight --target 1.35
./k8s-preflight --context prod-eu --cert-days 60
```

| Option | Meaning |
|---|---|
| `--target X.Y` | Minor version you plan to upgrade to |
| `--context NAME` | kubeconfig context |
| `--cert-days N` | Warn if the API server certificate expires within N days (default 30) |
| `--no-color` | Plain output (`NO_COLOR` is honoured too) |

Exit codes: `0` all passed, `1` warnings only, `2` at least one failure. That makes it easy to gate a CI job or an upgrade runbook on it.

## Sample output

From the test scenario in `test/fixtures/scenario.sh` (a Kubernetes v1.34.1 API server seeded with a lagging node, a containerd 1.7 node, a blocking PDB and a few other classics):

```text
k8s-preflight 0.1.0 - read-only pre-upgrade checks
Context: envtest-1.34

== 1. Client/server version skew ==
         server v1.34.1, kubectl v1.34.1, target 1.35
  [PASS] Upgrade path v1.34.1 -> 1.35 is a single minor step.
  [PASS] kubectl is within +/-1 minor of the server.

== 2. Nodes: kubelet skew, runtime, kernel ==
         cp-1  kubelet=v1.34.1  runtime=containerd://2.1.3  kernel=6.12.94  ready=True
         worker-1  kubelet=v1.33.5  runtime=containerd://1.7.28  kernel=5.4.0-216-generic  ready=True
  [WARN] worker-1: kubelet v1.33.5 lags the control plane (allowed, but finish the last upgrade).
  [WARN] worker-1: containerd://1.7.28. Plan containerd 2.x before going past 1.35.
  [WARN] worker-1: kernel 5.4.0-216-generic is older than 5.8, so cgroup v2 is unlikely. A 1.35+ kubelet refuses cgroup v1 by default.
         worker-2  kubelet=v1.31.9  runtime=containerd://2.0.5  kernel=6.8.0-85-generic  ready=True
  [FAIL] worker-2: kubelet v1.31.9 would be more than 3 minors behind 1.35. Upgrade nodes first.
         cgroup version is not visible through the API. On each node run: stat -fc %T /sys/fs/cgroup/  (want cgroup2fs)

== 3. Deprecated API usage (apiserver_requested_deprecated_apis) ==
  [WARN] v1 endpoints is deprecated (no removal release set; not a blocker).
         The metric covers only this API server instance since its last restart. Scan manifests/Helm releases with Pluto too.

== 4. etcd health (via API server health checks) ==
  [PASS] API server reports etcd ready (/readyz/etcd).
         etcd not visible as a static pod (managed or external etcd).
         Reminder: take an etcd snapshot AND test-restore it before the upgrade.

== 5. PodDisruptionBudgets that would block drains ==
  [FAIL] PDB shop/web allows 0 disruptions (1 pods). kubectl drain will hang.

== 6. Pending and failing pods ==
  [WARN] 2 Pending pod(s). Drained workloads may have nowhere to go:
           ingress-nginx/controller
           shop/web

== 7. Certificate expiry hints ==
  [PASS] API server certificate valid for 364 more days (Oct 12 05:33:57 2027 GMT).
         kubeadm clusters: run 'kubeadm certs check-expiration' on a control-plane node. 'kubeadm upgrade apply' renews certs by default.

== 8. Add-ons worth a look ==
  [WARN] Ingress NGINX (community controller) found. It was retired in March 2026; plan Gateway API / Ingress2Gateway.
  [WARN] kube-proxy runs in ipvs mode (deprecated in 1.35). Start testing nftables.

Summary: 4 passed, 7 warnings, 2 failed  (target 1.35)
Full checklist: https://agency42.se/en/articles/kubernetes-1-34-end-of-support-pre-flight-checklist
```

## What it can't see

Some things are invisible from the API, so the script reminds you instead of pretending:

- **cgroup version.** Run `stat -fc %T /sys/fs/cgroup/` on each node (`cgroup2fs` is what you want). A 1.35 kubelet refuses to start on cgroup v1 by default.
- **Deprecated APIs in manifests and Helm releases.** The metric only sees calls made to *this* API server instance since its last restart. Use [Pluto](https://github.com/FairwindsOps/pluto) for manifests and charts.
- **etcd backups.** `/readyz/etcd` says etcd answers, not that you can restore it. Take a snapshot and test-restore it.
- **Managed control planes.** On EKS, AKS and GKE some checks (etcd image, kube-proxy ConfigMap, certificates) are the provider's business and are reported as info.

## Testing

`test/` contains the output of the runs described in `test/README.md`: a clean API server, the seeded problem scenario, and a deliberately skipped minor (`--target 1.36`).

## Background

The checks follow the pre-flight checklist in [Kubernetes 1.34 end of support: a pre-flight checklist for 1.35](https://agency42.se/en/articles/kubernetes-1-34-end-of-support-pre-flight-checklist), which also covers the parts a script can't do for you: containerd 2.x migration, the skew-policy upgrade order and rollback planning.

## Contributing

Issues and pull requests are welcome. Keep it a single dependency-light script, keep it read-only, and add a line to `test/fixtures/scenario.sh` when you add a check.

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

Maintained by [Agency 42](https://agency42.se), Sweden's go-to Kubernetes specialists.
