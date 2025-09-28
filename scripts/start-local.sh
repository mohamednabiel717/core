#!/usr/bin/env bash
set -euo pipefail

REG_NAME=kind-registry
REG_PORT=5000
CLUSTER=infra-task

# Prerequisites validation
echo "[INFO] Checking prerequisites..."
for cmd in kind helm kubectl docker; do
  if ! command -v $cmd &> /dev/null; then
    echo "[ERROR] $cmd is not installed or not in PATH"
    exit 1
  fi
done

# Check Docker daemon
if ! docker info &> /dev/null; then
  echo "[ERROR] Docker daemon is not running"
  exit 1
fi

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER}$"; then
  echo "[WARN] Cluster '${CLUSTER}' already exists."
  echo -n "Delete and recreate? (y/N): "
  read -t 30 -n 1 -r REPLY 2>/dev/null || REPLY="N"
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[INFO] Deleting existing cluster..."
    kind delete cluster --name "${CLUSTER}"
  else
    echo "[INFO] Using existing cluster. Run 'kind delete cluster --name ${CLUSTER}' to remove it."
    exit 0
  fi
fi

# Start local registry if not running
echo "[INFO] Setting up local registry..."
if [ "$(docker inspect -f '{{.State.Running}}' "${REG_NAME}" 2>/dev/null || true)" != 'true' ]; then
  docker run -d --restart=always -p "127.0.0.1:${REG_PORT}:5000" --name "${REG_NAME}" registry:2
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to start local registry"
    exit 1
  fi
fi

# Create kind cluster with registry mirror + ingress ports
echo "[INFO] Creating kind cluster..."
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

if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to create kind cluster"
  exit 1
fi

# Connect registry to kind network
docker network connect "kind" "${REG_NAME}" 2>/dev/null || true

# Publish local-registry-hosting configmap
echo "[INFO] Configuring registry..."
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

# Install ingress-nginx
echo "[INFO] Installing ingress-nginx..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

# Add helm repositories
echo "[INFO] Adding helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Install metrics-server for HPA
echo "[INFO] Installing metrics-server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  -n kube-system \
  --set 'args={--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP}' \
  --wait

# Install monitoring stack
echo "[INFO] Installing monitoring stack (Prometheus, Alertmanager, Grafana)..."
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f k8s/monitoring-values.yaml \
  --wait

# Configure PagerDuty integration
if [ -n "${PD_ROUTING_KEY:-}" ]; then
  echo "[INFO] Configuring PagerDuty integration..."
  kubectl create secret generic pagerduty-secret \
    --from-literal=routing-key="$PD_ROUTING_KEY" \
    -n monitoring --dry-run=client -o yaml | kubectl apply -f -
  
  if [ $? -eq 0 ]; then
    kubectl apply -f k8s/alertmanager-config.yaml
    echo "[INFO] PagerDuty integration configured successfully"
  else
    echo "[ERROR] Failed to create PagerDuty secret"
    exit 1
  fi
else
  echo "[WARN] PD_ROUTING_KEY not set. PagerDuty alerts will not work."
  echo "[WARN] Set it with: export PD_ROUTING_KEY=your_pagerduty_integration_key"
fi
# Install logging stack
echo "[INFO] Installing logging stack (Loki + Promtail)..."
kubectl create ns logging 2>/dev/null || true
helm upgrade --install loki grafana/loki-stack -n logging \
  -f k8s/loki-values.yaml \
  --wait

echo "[INFO] Cluster setup complete."
echo "[INFO] Access Grafana: kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
