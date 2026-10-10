{{/*
Expand the name of the chart.
*/}}
{{- define "valheim.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "valheim.fullname" -}}
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
{{- define "valheim.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "valheim.labels" -}}
helm.sh/chart: {{ include "valheim.chart" . }}
{{ include "valheim.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "valheim.selectorLabels" -}}
app.kubernetes.io/name: {{ include "valheim.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Render only explicitly configured player lists, including empty lists.
*/}}
{{- define "valheim.playerLists" -}}
{{- $files := dict }}
{{- range $key, $filename := dict "adminList" "adminlist.txt" "bannedList" "bannedlist.txt" "permittedList" "permittedlist.txt" }}
  {{- $entries := index $ $key }}
  {{- if ne $entries nil }}
    {{- if not (kindIs "slice" $entries) }}
      {{- fail (printf "instances[].%s must be a list of quoted player IDs or null" $key) }}
    {{- end }}
    {{- range $entries }}
      {{- if not (kindIs "string" .) }}
        {{- fail (printf "instances[].%s entries must be quoted player IDs" $key) }}
      {{- end }}
    {{- end }}
    {{- $content := "" }}
    {{- if $entries }}
      {{- $content = printf "%s\n" (join "\n" $entries) }}
    {{- end }}
    {{- $_ := set $files $filename $content }}
  {{- end }}
{{- end }}
{{- toJson $files }}
{{- end }}

{{/* All pods share mount definitions; reject mixed managed/unmanaged lists. */}}
{{- define "valheim.managedPlayerLists" -}}
{{- $files := dict }}
{{- range $key, $filename := dict "adminList" "adminlist.txt" "bannedList" "bannedlist.txt" "permittedList" "permittedlist.txt" }}
  {{- $enabled := 0 }}
  {{- range $.Values.instances }}
    {{- if ne (index . $key) nil }}
      {{- $enabled = add1 $enabled }}
    {{- end }}
  {{- end }}
  {{- if $enabled }}
    {{- if ne (int $enabled) (len $.Values.instances) }}
      {{- fail (printf "instances[].%s must be configured for all instances or null/omitted for all instances because StatefulSet pods share file mounts; use [] for an empty managed list" $key) }}
    {{- end }}
    {{- $_ := set $files $filename true }}
  {{- end }}
{{- end }}
{{- toJson $files }}
{{- end }}

{{/* Build preset and setkey arguments for one instance. */}}
{{- define "valheim.worldArgs" -}}
{{- $root := index . "root" -}}
{{- $instance := index . "instance" -}}
{{- $args := list -}}
{{- $preset := $instance.preset -}}
{{- if $preset -}}
  {{- $args = append $args "-preset" -}}
  {{- $args = append $args $preset -}}
{{- end -}}
{{- $instanceModifiers := $instance.modifiers | default dict -}}
{{- $modifiers := mergeOverwrite (deepCopy $root.Values.valheimDedicatedServer.modifiers) $instanceModifiers -}}
{{- range $modifier, $value := $modifiers -}}
  {{- $args = append $args "-modifier" -}}
  {{- $args = append $args $modifier -}}
  {{- $args = append $args $value -}}
{{- end -}}
{{- $instanceSetKeys := $instance.setKeys | default list -}}
{{- $setKeys := uniq (concat $root.Values.valheimDedicatedServer.setKeys $instanceSetKeys) -}}
{{- range $key := $setKeys -}}
  {{- $args = append $args "-setkey" -}}
  {{- $args = append $args $key -}}
{{- end -}}
{{- join " " $args -}}
{{- end -}}
