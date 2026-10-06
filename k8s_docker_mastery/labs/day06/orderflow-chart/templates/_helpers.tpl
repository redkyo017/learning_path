{{/* Chart name. */}}
{{- define "orderflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified app name. With release "orderflow" this is "orderflow" (the release name already contains the chart name). */}}
{{- define "orderflow.fullname" -}}
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
Labels for one component. Call: include "orderflow.labels" (dict "root" . "component" "order-api")
`app` is kept for continuity with Day 3-5 selectors / NetworkPolicies. Each key appears exactly once.
*/}}
{{- define "orderflow.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .root.Chart.Name .root.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "orderflow.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: orderflow
app.kubernetes.io/component: {{ .component }}
app: {{ .component }}
{{- end }}

{{/* Immutable selector labels (a subset of the labels above). Same call shape as orderflow.labels. */}}
{{- define "orderflow.selectorLabels" -}}
app: {{ .component }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end }}

{{/* Pod-level securityContext: passes the `restricted` Pod Security Standard. 65532 = distroless "nonroot". */}}
{{- define "orderflow.podSecurityContext" -}}
runAsNonRoot: true
runAsUser: 65532
runAsGroup: 65532
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/* Container-level securityContext for `restricted`. */}}
{{- define "orderflow.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}

{{/*
Pod securityContext for the postgres-based containers. postgres:16-alpine has no USER (it runs as root), so with
runAsNonRoot we must set runAsUser; 70 is the image's `postgres` UID. fsGroup matters on block/CSI volumes (EBS); the
local-path volume on Docker Desktop is hostPath-backed (mode 0777) and the kubelet ignores fsGroup there.
*/}}
{{- define "orderflow.postgresPodSecurityContext" -}}
runAsNonRoot: true
runAsUser: 70
runAsGroup: 70
fsGroup: 70
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/* Startup / readiness / liveness probes. Call with .Values.probes. */}}
{{- define "orderflow.probes" -}}
startupProbe:
  httpGet: {path: {{ .startup.path }}, port: http}
  periodSeconds: {{ .startup.periodSeconds }}
  failureThreshold: {{ .startup.failureThreshold }}
readinessProbe:
  httpGet: {path: {{ .readiness.path }}, port: http}
  periodSeconds: {{ .readiness.periodSeconds }}
  failureThreshold: {{ .readiness.failureThreshold }}
livenessProbe:
  httpGet: {path: {{ .liveness.path }}, port: http}
  periodSeconds: {{ .liveness.periodSeconds }}
  failureThreshold: {{ .liveness.failureThreshold }}
{{- end }}

{{/* Fails the render when the grace period cannot fit preStop + app drain + the apps' 20s Shutdown timeout. */}}
{{- define "orderflow.validateShutdown" -}}
{{- $need := add (int .Values.shutdown.preStopSleepSeconds) (int .Values.shutdown.drainDelaySeconds) 20 | int }}
{{- if lt (int .Values.shutdown.terminationGracePeriodSeconds) $need }}
{{- fail (printf "shutdown.terminationGracePeriodSeconds=%v is too short: need >= preStopSleepSeconds + drainDelaySeconds + 20 = %d" .Values.shutdown.terminationGracePeriodSeconds $need) }}
{{- end }}
{{- end }}

{{/* preStop hook (native sleep action; omitted when 0). */}}
{{- define "orderflow.lifecycle" -}}
{{- if gt (int .Values.shutdown.preStopSleepSeconds) 0 }}
lifecycle:
  preStop:
    sleep:
      seconds: {{ int .Values.shutdown.preStopSleepSeconds }}
{{- end }}
{{- end }}

{{/* topologySpreadConstraints for one component. Same call shape as orderflow.labels. */}}
{{- define "orderflow.topologySpread" -}}
{{- if .root.Values.topologySpread.enabled }}
topologySpreadConstraints:
{{- range .root.Values.topologySpread.constraints }}
  - maxSkew: {{ .maxSkew }}
    topologyKey: {{ .topologyKey }}
    whenUnsatisfiable: {{ .whenUnsatisfiable }}
    labelSelector:
      matchLabels:
        {{- include "orderflow.selectorLabels" $ | nindent 8 }}
{{- end }}
{{- end }}
{{- end }}

{{/* Database host: the in-chart StatefulSet's headless Service, or the external host. */}}
{{- define "orderflow.postgresHost" -}}
{{- if .Values.postgres.enabled }}{{ include "orderflow.fullname" . }}-postgres{{ else }}{{ required "postgres.externalHost is required when postgres.enabled=false" .Values.postgres.externalHost }}{{ end }}
{{- end }}

{{/* Name of the Secret holding POSTGRES_PASSWORD. */}}
{{- define "orderflow.postgresSecretName" -}}
{{- if .Values.postgres.enabled }}
{{- default (printf "%s-postgres-auth" (include "orderflow.fullname" .)) .Values.postgres.auth.existingSecret }}
{{- else }}
{{- required "postgres.auth.existingSecret is required when postgres.enabled=false (the chart renders no Secret for an external database; the init container and migration Job read POSTGRES_PASSWORD from it)" .Values.postgres.auth.existingSecret }}
{{- end }}
{{- end }}

{{/* Service name + port for a route/ingress path "service:" key. */}}
{{- define "orderflow.backendName" -}}
{{- printf "%s-%s" (include "orderflow.fullname" .root) .service }}
{{- end }}
{{- define "orderflow.backendPort" -}}
{{- if eq .service "order-api" }}{{ .root.Values.orderApi.service.port }}
{{- else if eq .service "payment" }}{{ .root.Values.paymentService.service.port }}
{{- else if eq .service "notification" }}{{ .root.Values.notificationService.service.port }}
{{- else }}{{ fail (printf "unknown service %q (use order-api, payment or notification)" .service) }}
{{- end }}
{{- end }}
