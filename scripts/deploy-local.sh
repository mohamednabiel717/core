#!/usr/bin/env bash
set -euo pipefail

NS=guestbook
REG=localhost:5000
DBNS=data

kubectl get ns $NS >/dev/null 2>&1 || kubectl create ns $NS
kubectl get ns "$DBNS" >/dev/null 2>&1 || kubectl create ns "$DBNS"
kubectl get ns monitoring >/dev/null 2>&1 || kubectl create ns monitoring

# --- Alertmanager Configuration ---
echo "[*] Configuring Alertmanager"
# Create alertmanager-config secret from existing config
echo "    creating alertmanager-config secret..."
kubectl create secret generic alertmanager-config -n monitoring \
  --from-file=alertmanager.yml=secrets/alertmanager.yaml \
  --dry-run=client -o yaml | kubectl apply -f -


# --- Grafana Dashboards ---
echo "[*] Deploying Grafana dashboards"
DASH_SRC="k8s/dashboards/app-starter.json"
CM_TPL="k8s/dashboards/app-starter-cm.yaml.tpl"
CM_OUT="k8s/dashboards/app-starter-cm.yaml"

# Create the ConfigMap directly
echo "    creating ConfigMap with dashboard JSON..."
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

# --- MongoDB (Homemade) ---
# Install our local Mongo chart (separate release)
helm upgrade --install mongodb src/mongodb/charts/mongodb \
  -n "$DBNS" -f k8s/values-dev/mongodb.yaml --wait

# build & push backend
docker build -t ${REG}/python-guestbook-backend:dev src/backend
docker push ${REG}/python-guestbook-backend:dev
kind load docker-image ${REG}/python-guestbook-backend:dev --name infra-task

# deploy backend chart
helm upgrade --install backend src/backend/charts/backend \
  -n $NS -f k8s/values-dev/backend.yaml --wait

# build & push frontend
docker build -t ${REG}/python-guestbook-frontend:dev src/frontend
docker push ${REG}/python-guestbook-frontend:dev
kind load docker-image ${REG}/python-guestbook-frontend:dev --name infra-task

# deploy frontend chart
helm upgrade --install frontend src/frontend/charts/frontend \
  -n $NS -f k8s/values-dev/frontend.yaml --wait

kubectl -n $NS get pods,svc,ingress
kubectl -n "$NS" get pods,svc,ingress
echo "Mongo in '$DBNS' ns:"
kubectl -n "$DBNS" get pods,svc

echo "➡ Services ready. Try:"
echo "   curl -v http://localhost/api/healthz      # backend health"
echo "   curl -v http://localhost/               # frontend app"
echo "   curl -v http://localhost/api/metrics | head  # backend metrics"