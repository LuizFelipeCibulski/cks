#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=immutable
J() { kubectl -n $NS get deploy logger -o jsonpath="$1" 2>/dev/null; }

[ "$(J '{.spec.template.spec.containers[?(@.name=="logger")].securityContext.readOnlyRootFilesystem}')" == "true" ] \
  && ok "readOnlyRootFilesystem: true no container logger" || fail "container logger sem readOnlyRootFilesystem: true"

[ -n "$(J '{.spec.template.spec.volumes[?(@.name=="logs")].emptyDir}')" ] \
  && ok "volume emptyDir 'logs' definido" || fail "volume emptyDir 'logs' não encontrado"

mp=$(J '{.spec.template.spec.containers[?(@.name=="logger")].volumeMounts[?(@.name=="logs")].mountPath}')
[ "${mp%/}" == "/app/logs" ] && ok "volume 'logs' montado em /app/logs" || fail "volume 'logs' não está montado em /app/logs (mountPath='$mp')"

others=$(J '{range .spec.template.spec.containers[?(@.name=="logger")].volumeMounts[*]}{.mountPath}{"\n"}{end}' | grep -v '^/app/logs/\?$' | grep -v '^/var/run/secrets/kubernetes.io/' | grep -v '^$')
[ -z "$others" ] && ok "nenhum outro caminho gravável montado" || fail "há outros volumes montados: $others"

if kubectl -n $NS rollout status deploy/logger --timeout=60s >/dev/null 2>&1; then ok "rollout concluído"; else fail "rollout não concluído"; fi

POD=$(kubectl -n $NS get pod -l app=logger -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' 2>/dev/null | head -1)
if [ -n "$POD" ]; then
  if kubectl -n $NS exec "$POD" -c logger -- touch /cks-test >/dev/null 2>&1; then
    fail "ainda é possível escrever em / dentro do container"
  else
    ok "root filesystem é somente leitura"
  fi
  kubectl -n $NS exec "$POD" -c logger -- touch /tmp/cks-test >/dev/null 2>&1 && fail "/tmp ainda é gravável" || ok "/tmp não é gravável"
  a=$(kubectl -n $NS exec "$POD" -c logger -- wc -l /app/logs/app.log 2>/dev/null | awk '{print $1}')
  sleep 6
  b=$(kubectl -n $NS exec "$POD" -c logger -- wc -l /app/logs/app.log 2>/dev/null | awk '{print $1}')
  if [ -n "$b" ] && [ "${b:-0}" -gt "${a:-0}" ]; then ok "/app/logs/app.log está sendo atualizado"; else fail "/app/logs/app.log não está sendo atualizado"; fi
else
  fail "nenhum Pod Running do Deployment logger"
fi

finish
