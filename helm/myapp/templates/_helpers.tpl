{{/*
Expand the name of the chart/workload.
*/}}
{{- define "myapp.name" -}}
{{- default .Values.app.name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "myapp.name" . }}
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
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "myapp.labels" -}}
app: {{ include "myapp.name" . }}
helm.sh/chart: {{ include "myapp.chart" . }}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component helpers
*/}}
{{- define "myapp.componentName" -}}
{{- printf "%s-%s" (include "myapp.fullname" .root) .component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "myapp.componentLabels" -}}
{{ include "myapp.labels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "myapp.componentSelectorLabels" -}}
{{ include "myapp.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Frequently used names.
*/}}
{{- define "myapp.appDeploymentName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "app") }}
{{- end }}
{{- define "myapp.appServiceName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "app-svc") }}
{{- end }}
{{- define "myapp.appConfigMapName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "app-config") }}
{{- end }}
{{- define "myapp.appSecretName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "app-secret") }}
{{- end }}
{{- define "myapp.prometheusName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "prometheus") }}
{{- end }}
{{- define "myapp.prometheusCfgName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "prometheus-config") }}
{{- end }}
{{- define "myapp.grafanaName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "grafana") }}
{{- end }}
{{- define "myapp.grafanaDashboardsName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "grafana-dashboards") }}
{{- end }}
{{- define "myapp.grafanaProvisioningName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "grafana-provisioning") }}
{{- end }}
{{/* ... existing app definitions ... */}}

{{- define "myapp.modelDeploymentName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "model") }}
{{- end }}

{{- define "myapp.modelServiceName" -}}
{{ include "myapp.componentName" (dict "root" . "component" .Values.model.name) }}
{{- end }}

{{- define "myapp.modelConfigMapName" -}}
{{ include "myapp.componentName" (dict "root" . "component" "model-config") }}
{{- end }}