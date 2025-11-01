{{/*
Expand the name of the chart.
*/}}
{{- define "express-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "express-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "express-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "express-app.labels" -}}
helm.sh/chart: {{ include "express-app.chart" . }}
{{ include "express-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for default
*/}}
{{- define "express-app.default.selectorLabels" -}}
app.kubernetes.io/name: {{ include "express-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: default
app: {{ .Values.global.appName }}
type: default
{{- end }}

{{/*
Selector labels for PR branch
*/}}
{{- define "express-app.pr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "express-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: pr
app: {{ .Values.global.appName }}
branch: {{ .prBranch }}
{{- end }}

{{/*
Generate service name for default
*/}}
{{- define "express-app.default.serviceName" -}}
{{- printf "%s-default" (include "express-app.fullname" .) }}
{{- end }}

{{/*
Generate service name for PR branch
*/}}
{{- define "express-app.pr.serviceName" -}}
{{- printf "%s-%s" (include "express-app.fullname" .) .prBranch }}
{{- end }}

{{/*
Generate deployment name for default
*/}}
{{- define "express-app.default.deploymentName" -}}
{{- printf "%s-default" (include "express-app.fullname" .) }}
{{- end }}

{{/*
Generate deployment name for PR branch
*/}}
{{- define "express-app.pr.deploymentName" -}}
{{- printf "%s-%s" (include "express-app.fullname" .) .prBranch }}
{{- end }}

{{/*
Generate ingress name for default
*/}}
{{- define "express-app.default.ingressName" -}}
{{- printf "%s-default" (include "express-app.fullname" .) }}
{{- end }}

{{/*
Generate ingress name for PR branch
*/}}
{{- define "express-app.pr.ingressName" -}}
{{- printf "%s-%s" (include "express-app.fullname" .) .prBranch }}
{{- end }}

