#!/usr/bin/env bash
set -euo pipefail

REG_NAME=kind-registry
REG_PORT=5000
CLUSTER=infra-task

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER}$"; then
  echo "⚠️  Cluster '${CLUSTER}' already exists."
  read -p "Delete and recreate? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Deleting existing cluster..."
    kind delete cluster --name "${CLUSTER}"
  else
    echo "ℹ️  Using existing cluster. Run 'kind delete cluster --name ${CLUSTER}' to remove it."
    exit 0
  fi
fi

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
    hostPort: 8080
  - containerPort: 443
    hostPort: 8443
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

# install metrics-server (for HPA)
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

helm upgrade --install metrics-server metrics-server/metrics-server \
  -n kube-system \
  --set 'args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP}' \
  --wait

# 6) monitoring stack (Prometheus, Alertmanager, Grafana)
# Install monitoring stack (Prometheus, Alertmanager, Grafana)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f k8s/monitoring-values.yaml \
  --wait
# 7) logging stack (Loki + Promtail)
kubectl create ns logging 2>/dev/null || true
helm upgrade --install loki grafana/loki-stack -n logging \
  --set grafana.enabled=false \
  --set prometheus.enabled=false \
  --wait

echo "✅ Cluster up. Grafana: 'kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80'"
