apiVersion: v1
kind: ConfigMap
metadata:
  name: app-starter-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  app-starter.json: |
    {{DASH_JSON}}