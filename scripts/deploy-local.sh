#!/usr/bin/env bash
set -euo pipefail

FRONTEND_NS=frontend
BACKEND_NS=backend
REG=localhost:5000
DBNS=data

kubectl get ns $FRONTEND_NS >/dev/null 2>&1 || kubectl create ns $FRONTEND_NS
kubectl get ns $BACKEND_NS >/dev/null 2>&1 || kubectl create ns $BACKEND_NS
kubectl get ns "$DBNS" >/dev/null 2>&1 || kubectl create ns "$DBNS"
kubectl get ns monitoring >/dev/null 2>&1 || kubectl create ns monitoring



# --- AlertmanagerConfig & PagerDuty secret ---
echo "[*] Wiring PagerDuty"
if [[ -z "${PD_ROUTING_KEY:-}" ]]; then
  echo "❌ Error: PD_ROUTING_KEY environment variable is required"
  echo "   Set it with: export PD_ROUTING_KEY='your-pagerduty-integration-key'"
  exit 1
fi

kubectl -n monitoring create secret generic pagerduty-secret \
  --from-literal=routing-key="${PD_ROUTING_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n monitoring apply -f k8s/alertmanager-config.yaml

# Bounce Alertmanager to pick up changes quickly
kubectl -n monitoring rollout restart statefulset/alertmanager-monitoring-kube-prometheus-alertmanager
kubectl -n monitoring rollout status  statefulset/alertmanager-monitoring-kube-prometheus-alertmanager --timeout=180s

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
  -n $BACKEND_NS -f k8s/values-dev/backend.yaml --wait

# build & push frontend
docker build -t ${REG}/python-guestbook-frontend:dev src/frontend
docker push ${REG}/python-guestbook-frontend:dev
kind load docker-image ${REG}/python-guestbook-frontend:dev --name infra-task

# deploy frontend chart
helm upgrade --install frontend src/frontend/charts/frontend \
  -n $FRONTEND_NS -f k8s/values-dev/frontend.yaml --wait

echo "Frontend in '$FRONTEND_NS' ns:"
kubectl -n $FRONTEND_NS get pods,svc,ingress
echo "Backend in '$BACKEND_NS' ns:"
kubectl -n $BACKEND_NS get pods,svc,ingress
echo "Mongo in '$DBNS' ns:"
kubectl -n "$DBNS" get pods,svc

echo "➡ Services ready. Try:"
echo "   curl -v http://localhost/               # frontend app"
echo "   Frontend → Backend communication working internally"