# Test runs

Environment (12 Oct 2026): kubectl v1.34.1 against a real kube-apiserver v1.34.1 + etcd from
controller-runtime's `setup-envtest` (no kubelets, scheduler or controller-manager).
Nodes, PDB status and pods are seeded through the API by `fixtures/scenario.sh`.

| File | Scenario | Result |
|---|---|---|
| run1-clean-envtest.txt | Fresh API server, no nodes | warnings only (no nodes, v1 Endpoints call) |
| run2-seeded-problems-envtest.txt | After `fixtures/scenario.sh` | 4 pass / 7 warn / 2 fail, exit 2 |
| run3-target-skip-envtest.txt | Same, `--target 1.36` | skipped minor + containerd 1.x flagged as FAIL |

Not covered here: kubelet metrics proxy (`kubelet_cri_losing_support`), etcd static-pod image detection and
crash-loop detection need real kubelets. Run against kind or a real cluster before a release.
