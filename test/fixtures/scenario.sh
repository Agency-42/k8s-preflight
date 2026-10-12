#!/usr/bin/env bash
# Seeds a bare API server (envtest: kube-apiserver + etcd, no kubelets) with
# objects that should trigger k8s-preflight warnings/failures.
set -euo pipefail
mknode() { # name kubelet runtime kernel
  kubectl create -f - <<Y
apiVersion: v1
kind: Node
metadata: {name: $1}
Y
  kubectl patch node "$1" --subresource=status --type=merge -p "{\"status\":{\"nodeInfo\":{\"kubeletVersion\":\"$2\",\"containerRuntimeVersion\":\"$3\",\"kernelVersion\":\"$4\",\"operatingSystem\":\"linux\",\"architecture\":\"amd64\",\"bootID\":\"x\",\"kernelVersion\":\"$4\",\"kubeProxyVersion\":\"\",\"machineID\":\"x\",\"osImage\":\"test\",\"systemUUID\":\"x\"},\"conditions\":[{\"type\":\"Ready\",\"status\":\"True\",\"reason\":\"KubeletReady\",\"message\":\"seeded\",\"lastHeartbeatTime\":\"2026-10-12T06:00:00Z\",\"lastTransitionTime\":\"2026-10-12T06:00:00Z\"}]}}"
}
mknode cp-1     v1.34.1 containerd://2.1.3  6.12.94
mknode worker-1 v1.33.5 containerd://1.7.28 5.4.0-216-generic
mknode worker-2 v1.31.9 containerd://2.0.5  6.8.0-85-generic
kubectl create ns shop
kubectl -n shop create serviceaccount default
# No scheduler/controller-manager in envtest, so a bare pod stays Pending
kubectl -n shop run web --image=nginx:1.27 --labels=app=web
kubectl -n shop create pdb web --selector=app=web --min-available=1
kubectl -n shop patch pdb web --subresource=status --type=merge -p '{"status":{"disruptionsAllowed":0,"expectedPods":1,"currentHealthy":1,"desiredHealthy":1,"observedGeneration":1}}'
kubectl create ns ingress-nginx
kubectl -n ingress-nginx create serviceaccount default
kubectl -n ingress-nginx run controller --image=registry.k8s.io/ingress-nginx/controller:v1.15.1 --labels=app.kubernetes.io/name=ingress-nginx
kubectl -n kube-system create configmap kube-proxy --from-literal=config.conf=$'apiVersion: kubeproxy.config.k8s.io/v1alpha1\nkind: KubeProxyConfiguration\nmode: "ipvs"\n'
kubectl get endpoints -A >/dev/null   # a deprecated v1 API call shows up in the metric
