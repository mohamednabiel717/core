# Guestbook Application - Infrastructure Solution

  

A Kubernetes deployment of a Python guestbook application with comprehensive monitoring, logging, and alerting capabilities.

  

## 🏗️ Technical Design

  

### Architecture Overview

```

┌─────────────────────┐

│ Ingress (nginx) │ HTTP

│ NodePort on kind ├──────────┐

└─────────────────────┘ │

│

┌────────────▼──────────┐

│ frontend ns │

│ ┌─────────────────────┤

│ │ frontend Service ├──► Flask UI

│ │ (Python + metrics) │

│ └─────────────────────┤

└─────────────────────────┘

│

│ HTTP /api/*

┌────────────▼──────────┐

│ backend ns │

│ ┌─────────────────────┤

│ │ backend Service ├──► Flask API (/api)

│ │ (Python + metrics) │ + Histogram metrics

│ └─────────────────────┤

└─────────────────────────┘

│

│ TCP 27017

┌────────────▼──────────┐

│ data ns │

│ ┌─────────────────────┤

│ │ mongodb Service ├──► MongoDB

│ │ + exporter (9216) │ + Backup CronJob

│ └─────────────────────┤

└─────────────────────────┘

│

│ Metrics Collection

┌───────────────────────┼───────────────────────┐

│ Observability Stack │

│ ┌─────────────┐ ┌─────────────┐ ┌──────────┐ │

│ │ Prometheus │ │ Grafana │ │ Loki │ │

│ │ (metrics) │ │ (dashboard) │ │ (logs) │ │

│ └─────────────┘ └─────────────┘ └──────────┘ │

│ ┌─────────────┐ ┌─────────────┐ │

│ │Alertmanager │ │ PagerDuty │ │

│ │ (routing) │ │ (incidents) │ │

│ └─────────────┘ └─────────────┘ │

└─────────────────────────────────────────────────┘

```

  

### Technology Stack

- **Container Orchestration**: Kubernetes (Kind for local development)

- **Package Management**: Helm 3

- **Monitoring**: Prometheus + Grafana + kube-prometheus-stack

- **Logging**: Loki + Promtail

- **Alerting**: Alertmanager + PagerDuty

- **Ingress**: NGINX Ingress Controller

- **Scaling**: Horizontal Pod Autoscaler (HPA) + Metrics Server

- **Registry**: Local Docker Registry

  

## ✅ Requirements Coverage

  

### Task Requirements vs Implementation

  

| Requirement | Status | Implementation |

|-------------|--------|----------------|

| **Local cluster setup** | ✅ Complete | Kind cluster with ingress, registry, and networking |

| **Monitoring stack** | ✅ Complete | Prometheus, Grafana, Alertmanager with custom dashboards |

| **Logging stack** | ✅ Complete | Loki + Promtail for centralized logging |

| **Build & deploy script** | ✅ Complete | Automated scripts with error handling and validation |

| **Service observability** | ✅ Complete | ServiceMonitors, custom metrics, health checks |

| **PagerDuty integration** | ✅ Complete | Alertmanager → PagerDuty with severity-based routing |

| **Documentation** | ✅ Complete | Comprehensive README with setup instructions |

  

### Additional Enhancements (Beyond Requirements)

- **Horizontal Pod Autoscaling** for dynamic scaling

- **Pod Disruption Budgets** for high availability

- **Resource Quotas** for resource management

- **Custom Grafana Dashboard** with 14 monitoring panels

- **Backup Strategy** for MongoDB with CronJob

- **Health Checks** (readiness/liveness probes)

- **Production-ready Helm Charts** with templating

  

## 🔧 Quick Deployment Guide

  

### 1. PagerDuty Setup (Required for Alerting)

  

#### Get PagerDuty Integration Key:

1. **Login to PagerDuty** → Go to **Services** → **Service Directory**

2. **Create New Service** or select existing service

3. **Add Integration** → **Events API v2**

4. **Copy the Integration Key** (starts with `R0...`)

  

#### Set Environment Variable:

```bash

# Required: Set your PagerDuty integration key

export PD_ROUTING_KEY=R03EFNPT17TDILI3O4IAZ4563S4UTLVE # Replace with your key

  

```

  

### 2. Two-Script Deployment

  

#### Step 1: Infrastructure Setup

```bash

# Creates Kind cluster + monitoring stack + logging

./scripts/start-local.sh

```

**What it does:**

- ✅ Creates Kind cluster with ingress

- ✅ Installs Prometheus + Grafana + Alertmanager

- ✅ Configures PagerDuty integration

- ✅ Sets up Loki logging stack

- ✅ Installs metrics server for HPA

  

#### Step 2: Application Deployment

```bash

# Builds images + deploys frontend/backend/mongodb

./scripts/deploy-local.sh

```

**What it does:**

- ✅ Builds Docker images for frontend/backend

- ✅ Deploys MongoDB with metrics exporter

- ✅ Deploys backend with histogram metrics

- ✅ Deploys frontend with ingress routing

- ✅ Configures ServiceMonitors for Prometheus

  

### 3. Access Services

  

```bash

# Application

curl http://localhost:8080

  

# Grafana Dashboard

kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80

# Access: http://localhost:3000 (admin/admin)

  

# Prometheus

kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090

  

# Alertmanager

kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093

# Access: http://localhost:9093

```

  

### 4. Verification & Cleanup

  

#### Verify Deployment:

```bash

# Check all pods are running

kubectl get pods -A

  

# Test alerting (should show active alerts)

curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels.alertname'

```

  

#### Cleanup:

```bash

# Remove everything

kind delete cluster --name infra-task

docker stop kind-registry && docker rm kind-registry

```

  

### 5. What Gets Deployed

  

#### Infrastructure Components:

- **Kind Cluster**: Local Kubernetes with ingress

- **Monitoring**: Prometheus, Grafana, Alertmanager

- **Logging**: Loki + Promtail

- **Alerting**: PagerDuty integration with severity routing

- **Scaling**: HPA + Metrics Server

  

#### Application Components:

- **Frontend**: Python Flask UI (namespace: frontend)

- **Backend**: Python Flask API with metrics (namespace: backend)

- **MongoDB**: Database with exporter + backup (namespace: data)

- **Custom Dashboard**: 14-panel Grafana dashboard

- **Alert Rules**: 7 custom alerts for each service

  

### 4. Key Implementation Changes

  

#### Docker Security Enhancements:

```diff

# Copy the rest of the working directory contents into the container at /app

COPY . .

  

+ # Create non-root user with numeric UID

+ RUN groupadd -r -g 1001 appuser && useradd -r -u 1001 -g appuser appuser

+ RUN chown -R appuser:appuser /app

+ USER 1001

  

# Run app.py when the container launches

ENTRYPOINT ["python", "back.py"]

```

  

**Security Impact:**

- ❌ **Before**: Containers ran as root (UID 0) - security vulnerability

- ✅ **After**: Containers run as non-root user (UID 1001) - security best practice

  

### 5. Security Implementations

  

#### Health Checks

```yaml

readinessProbe:

httpGet: { path: /healthz, port: http }

initialDelaySeconds: 5

periodSeconds: 10

livenessProbe:

httpGet: { path: /healthz, port: http }

initialDelaySeconds: 10

periodSeconds: 20

```

  

#### Resource Management

```yaml

resources:

requests: { cpu: 200m, memory: 256Mi }

limits: { cpu: 800m, memory: 512Mi }

```

  

#### Pod Disruption Budgets

```yaml

apiVersion: policy/v1

kind: PodDisruptionBudget

metadata:

name: {{ include "backend.fullname" . }}-pdb

spec:

minAvailable: {{ .Values.pdb.minAvailable }}

```

  

### 5. Scaling Solutions

  

#### Horizontal Pod Autoscaler

```yaml

apiVersion: autoscaling/v2

kind: HorizontalPodAutoscaler

spec:

minReplicas: {{ .Values.hpa.minReplicas }}

maxReplicas: {{ .Values.hpa.maxReplicas }}

metrics:

- type: Resource

resource:

name: cpu

target:

type: Utilization

averageUtilization: 70

```

  

### 6. Monitoring & Observability

  

#### Prometheus Integration

```yaml

# ServiceMonitor for metrics collection

apiVersion: monitoring.coreos.com/v1

kind: ServiceMonitor

metadata:

name: {{ include "backend.fullname" . }}

spec:

selector:

matchLabels: {{- include "backend.selectorLabels" . | nindent 6 }}

endpoints:

- port: http

interval: {{ .Values.prometheus.serviceMonitor.interval }}

```

  

#### Custom Alerting Rules

```yaml

# PrometheusRule for custom alerts

- alert: BackendHighErrorRate

expr: job:http_5xx_rate:ratio > {{ .Values.prometheus.rule.errorRateThreshold }}

for: 5m

labels: { severity: critical, service: backend }

annotations: { summary: "Backend 5xx error rate > 5% for 5m" }

```

  

### 7. Dashboards & Visualization

  

#### Custom Grafana Dashboard (14 Panels)

- **Performance Metrics**: RPS, Error Rates, Latency

- **Infrastructure**: CPU, Memory, Storage I/O

- **Database**: MongoDB operations and connections

- **Alerting**: Active alerts table

- **Logs**: Application logs integration

  

### 8. Alerting & Incident Management

  

#### PagerDuty Integration

```yaml

# Embedded Alertmanager configuration

alertmanager:

config:

route:

group_by: ['alertname', 'cluster', 'service']

repeat_interval: 12h

routes:

- match: { severity: critical }

receiver: 'pagerduty-critical'

receivers:

- name: 'pagerduty-critical'

pagerduty_configs:

- routing_key_file: /etc/alertmanager/secrets/pagerduty-secret/routing-key

severity: critical

```

  

### 9. Logging Infrastructure

  

#### Centralized Logging with Loki

```yaml

# Loki configuration

loki:

persistence:

enabled: true

size: 5Gi

config:

schema_config:

configs:

- from: 2020-10-24

store: boltdb-shipper

object_store: filesystem

```

  

### 10. Charts & Package Management

  

#### Why Custom Charts Instead of Public Helm Charts for mongodb?

  

**Problem with Public Charts:**

- **ARM Compatibility**: Many charts don't support Apple Silicon (M1/M2) Macs

  

#### MongoDB Custom Chart Solution:

```yaml

# ARM64 compatible image for Apple Silicon

image:

repository: mongodb/mongodb-community-server

tag: 7.0.14-ubuntu2204 # ARM64 support

  

# Built-in metrics exporter

exporter:

image:

repository: percona/mongodb_exporter

tag: "0.40.0" # ARM64 compatible

```

  

**Custom Chart Benefits:**

- ✅ **ARM64 Support**: Works on Apple Silicon Macs

- ✅ **Lightweight**: Minimal resource footprint for local dev

- ✅ **Integrated Monitoring**: Built-in Prometheus exporter

- ✅ **Backup Strategy**: Automated CronJob backups

- ✅ **Alert Rules**: Database-specific monitoring

- ✅ **Production Ready**: Proper StatefulSet with persistence

  

#### Frontend/Backend Custom Charts:

**Why not use generic charts?**

- **Specific Requirements**: Need exact ServiceMonitor labels for Prometheus

- **Custom Metrics**: Backend requires histogram metrics configuration

- **Ingress Integration**: Frontend needs specific ingress routing

- **Resource Optimization**: Tailored CPU/memory limits for local development

  
  
  

## 📊 Monitoring & Alerting

  

### Available Dashboards

- **Guestbook Application Dashboard**: Custom 14-panel dashboard

- **Kubernetes Cluster Monitoring**: Default kube-prometheus-stack dashboards

- **Node Exporter**: System-level metrics

- **MongoDB**: Database performance metrics

  

### Alert Rules

- **Application**: High error rates, service down, high latency

- **Infrastructure**: High CPU/memory usage, pod crash looping

- **Database**: MongoDB connection issues, high operations

- **Cluster**: etcd issues, node problems

  

### PagerDuty Integration

- **Critical alerts**: Immediate notification

- **Warning alerts**: Grouped notifications

- **12-hour repeat interval**: Prevents alert spam

- **Severity-based routing**: Different handling per severity

  

## 🔍 Troubleshooting

  

### Common Issues

1. **PagerDuty not receiving alerts**: Check `PD_ROUTING_KEY` environment variable

2. **Pods not starting**: Verify resource availability with `kubectl describe pod`

3. **Ingress not working**: Ensure ingress-nginx controller is running

4. **Metrics not showing**: Check ServiceMonitor labels match Prometheus selector

  
  
  

## 📈 Performance & Scaling

  

### Resource Allocation

- **Frontend**: 200m CPU, 256Mi RAM (scales 1-5 replicas)

- **Backend**: 200m CPU, 256Mi RAM (scales 1-5 replicas)

- **MongoDB**: 500m CPU, 512Mi RAM (StatefulSet)

- **Monitoring Stack**: ~2 CPU, 4Gi RAM total

  

### Scaling Triggers

- **CPU**: 70% utilization threshold

- **Memory**: 80% utilization threshold

- **Custom metrics**: HTTP request rate, error rate

  

### High Availability

- **Pod Disruption Budgets**: Prevent voluntary disruptions

- **Multiple replicas**: Frontend and backend can scale

- **Persistent storage**: MongoDB data survives pod restarts

- **Health checks**: Automatic pod replacement on failure

  

## 🚀 Production Recommendations & Next Steps

  

### Current Foundation

This implementation provides a solid base for production with security hardening, complete observability, and scalability features.

  

### Next Steps for Production Ready:

- **CI/CD Pipeline**: GitHub Actions for automated testing and deployment

- **GitOps**: ArgoCD for continuous deployment and configuration management

- **Enhanced Security**: Network policies, external secrets management (Vault/AWS Secrets Manager)

- **Production Infrastructure**: Managed Kubernetes (EKS/GKE/AKS), production-grade MongoDB replica sets

- **Advanced Monitoring**: SLI/SLO tracking, cost monitoring

- **Disaster Recovery**: Velero backups, multi-region deployment, chaos engineering

- **/DNS/SSL/TLS**: cert-manager and domain setups

- **Multi-Environment**: Separate dev/staging/prod configurations with proper promotion workflows