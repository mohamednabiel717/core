#!/usr/bin/env bash
set -euo pipefail

REG_NAME=kind-registry
REG_PORT=5000
CLUSTER=infra-task

# 0) start local registry if not running
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
  docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" registry:2
fi

# 1) kind cluster with registry mirror + ingress ports
cat <<EOF | kind create cluster --name "${CLUSTER}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${REG_PORT}"]
    endpoint = ["http://localhost:${REG_PORT}"]
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
EOF

# 2) connect registry to kind network
docker network connect "kind" "${REG_NAME}" 2>/dev/null || true

# 3) publish local-registry-hosting configmap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REG_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# 4) ingress-nginx
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

# 5) helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 6) monitoring stack (Prometheus, Alertmanager, Grafana)
kubectl create ns monitoring 2>/dev/null || true
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --wait

# 7) logging stack (Loki + Promtail)
kubectl create ns logging 2>/dev/null || true
helm upgrade --install loki grafana/loki-stack -n logging --wait

echo "✅ Cluster up. Grafana: 'kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80'"
