{{/*
Expand the name of the chart.
*/}}
{{- define "HAB.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "HAB.fullname" -}}
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
{{- define "HAB.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "HAB.labels" -}}
helm.sh/chart: {{ include "HAB.chart" . }}
{{ include "HAB.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "HAB.selectorLabels" -}}
app.kubernetes.io/name: {{ include "HAB.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "HAB.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "HAB.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a map of groups, and for each group, create a kubernetes recognizable node address for each node in that group, and return all addresses as a list
*/}}
{{- define "HAB.peersInGroup" -}}
{{- $groups := dict }}
{{- range .Values.nodeList }}
{{- $defaultGroup := print .name "-group" -}}
{{- if (or .enabled ( not ( hasKey . "enabled" ))) }}
{{- $_ := set $groups ( .group | default $defaultGroup ) list }}
{{- end }}
{{- end }}
{{- range $_, $nodeSet := .Values.nodeList }}
{{- if (or .enabled (not (hasKey . "enabled"))) }}
{{- $defaultGroup := print .name "-group" -}}
{{- range $index := until (int (.replicaCount | default 1)) }}
{{- $current := get $groups ( $nodeSet.group | default $defaultGroup ) }}
{{- $new := append $current (printf "%s-%s-%s-%d.%s-%s-%s.bitcoin.svc.cluster.local:%s" (include "HAB.fullname" $) $nodeSet.type $nodeSet.name $index (include "HAB.fullname" $) $nodeSet.type $nodeSet.name (get ($.Files.Get "node-types.yml" | fromYaml ) $nodeSet.type).ports.p2pPort) }}
{{- $_ := set $groups ( $nodeSet.group | default $defaultGroup ) $new }}
{{- end }}
{{- end }}
{{- end }}

{{- range .Values.additionalPeers }}
{{- if hasKey $groups .group }}
{{- $current := get $groups .group }}
{{- $new := append $current .addressAndPort }}
{{- $_ := set $groups .group ( $new | uniq ) }}
{{- end }}
{{- end }}

{{ $groups | toYaml}}
{{- end }}

{{/*
Validate that naming is unique
*/}}
{{- define "HAB.validateNames" -}}
{{- $names := list }}
{{- range .Values.nodeList }}
{{- if (or .enabled ( not ( hasKey . "enabled" ))) }}
{{- $names = append $names (printf "%s-%s-%s" (include "HAB.fullname" $) .type .name) }}
{{- end }}
{{- end }}
{{- if ne (len ($names | uniq)) (len $names) }}
{{ print "Error: Vallidation Error, each active node name must be unique, nodes names supplied: " ($names | toString) }}
{{- end }}
{{- end }}

{{/*
Validate that nPlusOne hosts, if given, do not also have nodes that select the same hosts.
*/}}
{{- define "HAB.validateHosts" -}}
{{- $hosts := list }}
{{- range .Values.nodeList }}
{{- if (or .enabled ( not ( hasKey . "enabled" ))) }}
{{- if .targetHosts }}
{{- range .targetHosts }}
{{- $hosts = append $hosts . }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- range .Values.nPlusOneHosts}}
{{- if has . $hosts }}
{{ print "Error: Vallidation Error, If a nPlusOneHosts is defined, each active node host must not include that host in its targetHosts list. Target Hosts supplied: " ($hosts | uniq | toString) ", nPlusOneHost: " . }}
{{- end }}
{{- end }}
{{- end }}
