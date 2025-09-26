#!/usr/bin/env bash
set -euo pipefail

NS=guestbook
REG=localhost:5000

kubectl get ns $NS >/dev/null 2>&1 || kubectl create ns $NS

# build & push backend
docker build -t ${REG}/python-guestbook-backend:dev ../src/backend
docker push ${REG}/python-guestbook-backend:dev
kind load docker-image ${REG}/python-guestbook-backend:dev --name infra-task

# deploy backend chart
helm upgrade --install backend ../src/backend/charts/backend \
  -n $NS -f ../k8s/values-dev/backend.yaml --wait

# build & push frontend
docker build -t ${REG}/python-guestbook-frontend:dev ../src/frontend
docker push ${REG}/python-guestbook-frontend:dev
kind load docker-image ${REG}/python-guestbook-frontend:dev --name infra-task

# deploy frontend chart
helm upgrade --install frontend ../src/frontend/charts/frontend \
  -n $NS -f ../k8s/values-dev/frontend.yaml --wait

kubectl -n $NS get pods,svc,ingress
echo "➡ Services ready. Try:"
echo "   curl -v http://localhost/api/healthz      # backend health"
echo "   curl -v http://localhost/               # frontend app"
echo "   curl -v http://localhost/api/metrics | head  # backend metrics"