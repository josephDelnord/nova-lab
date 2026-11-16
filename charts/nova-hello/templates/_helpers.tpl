# TP6-TP8: Helper templates pour le chart nova-hello
# Ce fichier contient des fonctions utiles réutilisables dans tous les templates

{{/*
Expands the name of the chart.
*/}}
{{- define "nova-hello.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Creates a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nova-hello.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Creates chart name and version as used by the chart label.
*/}}
{{- define "nova-hello.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "nova-hello.labels" -}}
helm.sh/chart: {{ include "nova-hello.chart" . }}
{{ include "nova-hello.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "nova-hello.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nova-hello.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create a basic ConfigMap
*/}}
{{- define "nova-hello.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "nova-hello.fullname" . }}-config
  labels:
    {{- include "nova-hello.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configmap.data }}
  {{ $key }}: |-
    {{- tpl $value $ | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Create a basic Secret
*/}}
{{- define "nova-hello.secret" -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ template "nova-hello.fullname" . }}-secret
  labels:
    {{- include "nova-hello.labels" . | nindent 4 }}
type: {{ .Values.secret.type | default "Opaque" }}
data:
  {{- range $key, $value := .Values.secret.data }}
  {{ $key }}: {{ tpl $value $ | b64enc | quote }}
  {{- end }}
{{- end -}}

{{/*
Create deployment name
*/}}
{{- define "nova-hello.deployment.name" -}}
{{- template "nova-hello.fullname" . -}}
{{- end -}}

{{/*
Create service name
*/}}
{{- define "nova-hello.service.name" -}}
{{- template "nova-hello.fullname" . -}}
{{- end -}}

{{/*
Create service account name
*/}}
{{- define "nova-hello.serviceAccountName" -}}
{{- default (include "nova-hello.fullname" .) .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
