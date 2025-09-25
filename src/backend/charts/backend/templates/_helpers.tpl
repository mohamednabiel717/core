{{- define "backend.name" -}}backend{{- end -}}
{{- define "backend.fullname" -}}{{ include "backend.name" . }}{{- end -}}
{{- define "backend.labels" -}}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/part-of: guestbook
{{- end -}}