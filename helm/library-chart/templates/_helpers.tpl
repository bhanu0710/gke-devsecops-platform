{{/*
Common labels — applied to all resources for consistent querying.
Required labels enforced by OPA K8sRequiredLabels policy: app, version, team.
*/}}
{{- define "library-chart.labels" -}}
app: {{ .Release.Name }}
version: {{ .Values.image.tag | default "latest" | quote }}
team: {{ .Values.team | default "platform" | quote }}
managed-by: helm
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default "latest" | quote }}
app.kubernetes.io/managed-by: Helm
{{- end -}}
