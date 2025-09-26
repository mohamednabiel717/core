{{- define "frontend.name" -}}frontend{{- end -}}
{{- define "frontend.fullname" -}}{{ include "frontend.name" . }}{{- end -}}
{{- define "frontend.labels" -}}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/part-of: guestbook
{{- end -}}
