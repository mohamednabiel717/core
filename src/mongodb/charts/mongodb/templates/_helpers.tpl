{{- define "mongodb.labels" -}}
app.kubernetes.io/name: mongodb
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: guestbook
{{- end }}
