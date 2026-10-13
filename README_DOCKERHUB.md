# k8s-preflight

Read-only checks for a Kubernetes cluster before a minor version upgrade (for example 1.34 → 1.35): version and kubelet skew, deprecated API usage, container runtime, etcd health, PodDisruptionBudgets that block drains, pending pods and API server certificate expiry. It only reads from the cluster and never changes anything.

- Source code: https://github.com/Agency-42/k8s-preflight
- Background and full checklist: [Kubernetes 1.34 end of support: a pre-flight checklist for 1.35](https://agency42.se/en/articles/kubernetes-1-34-end-of-support-pre-flight-checklist)
- Maintained by [Agency 42](https://agency42.se/kubernetes)

## Usage

Mount your kubeconfig read-only:

```bash
docker run --rm -v "$HOME/.kube/config:/kube/config:ro" -e KUBECONFIG=/kube/config \
  agency42/k8s-preflight --target 1.35
```

For clusters reachable only on localhost (kind, minikube), add `--network host`.

Options: `--target X.Y`, `--context NAME`, `--cert-days N`, `--no-color`, `-h/--help`.
Exit codes: `0` all passed, `1` warnings only, `2` at least one failure.

The image bundles kubectl v1.35.x, which talks to API servers 1.34–1.36 within the supported skew. Build with `--build-arg KUBECTL_VERSION=vX.Y.Z` to change it.

License: Apache-2.0
