#!/usr/bin/env bash
set -euo pipefail

FRONTEND_NS=frontend
BACKEND_NS=backend
REG=localhost:5000
DBNS=data

# Prerequisites validation
echo "[INFO] Checking prerequisites..."
for cmd in kubectl helm docker kind; do
  if ! command -v $cmd &> /dev/null; then
    echo "[ERROR] $cmd is not installed or not in PATH"
    exit 1
  fi
done

# Check if cluster exists
if ! kubectl cluster-info &> /dev/null; then
  echo "[ERROR] No active Kubernetes cluster found. Run start-local.sh first."
  exit 1
fi

# Create namespaces
echo "[INFO] Creating namespaces..."
for ns in $FRONTEND_NS $BACKEND_NS $DBNS; do
  kubectl get ns $ns >/dev/null 2>&1 || kubectl create ns $ns
done

echo "[INFO] Deploying applications..."

# Deploy Grafana dashboards
echo "[INFO] Deploying Grafana dashboards..."
DASH_SRC="k8s/dashboards/app-starter.json"
CM_OUT="k8s/dashboards/app-starter-cm.yaml"

if [ ! -f "$DASH_SRC" ]; then
  echo "[ERROR] Dashboard file $DASH_SRC not found"
  exit 1
fi

cat > $CM_OUT << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-starter-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  app-starter.json: |
EOF
# Add the JSON with proper indentation
sed 's/^/    /' $DASH_SRC >> $CM_OUT

kubectl apply -f $CM_OUT

# Install MongoDB
echo "[INFO] Installing MongoDB..."
helm upgrade --install mongodb src/mongodb/charts/mongodb \
  -n "$DBNS" -f k8s/values-dev/mongodb.yaml --wait

# Build and deploy backend
echo "[INFO] Building backend image..."
docker build -t ${REG}/python-guestbook-backend:dev src/backend
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to build backend image"
  exit 1
fi

docker push ${REG}/python-guestbook-backend:dev
kind load docker-image ${REG}/python-guestbook-backend:dev --name infra-task

echo "[INFO] Deploying backend..."
helm upgrade --install backend src/backend/charts/backend \
  -n $BACKEND_NS -f k8s/values-dev/backend.yaml --wait

# Build and deploy frontend
echo "[INFO] Building frontend image..."
docker build -t ${REG}/python-guestbook-frontend:dev src/frontend
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to build frontend image"
  exit 1
fi

docker push ${REG}/python-guestbook-frontend:dev
kind load docker-image ${REG}/python-guestbook-frontend:dev --name infra-task

echo "[INFO] Deploying frontend..."
helm upgrade --install frontend src/frontend/charts/frontend \
  -n $FRONTEND_NS -f k8s/values-dev/frontend.yaml --wait

echo "[INFO] Deployment complete. Checking status..."
echo "[INFO] Frontend pods:"
kubectl -n $FRONTEND_NS get pods
echo "[INFO] Backend pods:"
kubectl -n $BACKEND_NS get pods
echo "[INFO] MongoDB pods:"
kubectl -n "$DBNS" get pods

echo "[INFO] Services ready. Access frontend at: http://localhost:8080"