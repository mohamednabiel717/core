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

kubectl -n $NS get pods,svc,ingress
echo "➡ Backend ready. Try:"
echo "   curl -v http://localhost/healthz         # or http://localhost:8080/healthz if you used 8080 mapping"
echo "   curl -v http://localhost/metrics | head"