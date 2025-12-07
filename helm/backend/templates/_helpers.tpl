{{- define "backend.fullname" -}}
{{ printf "%s-backend-%s" .Release.Name .Values.color }}
{{- end }}
