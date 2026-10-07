#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

f=/opt/course/14/q2/privileged-pods.txt
if [ -f $f ]; then
  lines=$(tr -d ' \r' < $f | grep -v '^$')
  for e in team-alpha/debug-tools team-gamma/bootstrap; do
    echo "$lines" | grep -qx "$e" && ok "lista contém $e" || fail "lista não contém $e"
  done
  n=$(echo "$lines" | grep -cE '^team-beta/metrics-collector-[a-z0-9]+-[a-z0-9]+$')
  [ "$n" -ge 2 ] && ok "lista contém os Pods do Deployment metrics-collector" || fail "lista deveria conter os 2 Pods team-beta/metrics-collector-..."
  echo "$lines" | grep -qE '^team-alpha/(web|log-agent)$|^team-beta/api$|^team-gamma/worker$' \
    && fail "lista contém Pods que NÃO são privilegiados" || ok "lista sem falsos positivos"
else
  fail "$f não existe"
fi

for p in team-alpha/debug-tools team-gamma/bootstrap; do
  kubectl -n ${p%/*} get pod ${p#*/} >/dev/null 2>&1 && fail "Pod $p ainda existe" || ok "Pod $p deletado"
done
for p in team-alpha/web team-alpha/log-agent team-beta/api team-gamma/worker; do
  kubectl -n ${p%/*} get pod ${p#*/} >/dev/null 2>&1 && ok "Pod $p preservado" || fail "Pod $p (não privilegiado) foi removido"
done

if kubectl -n team-beta get deploy metrics-collector >/dev/null 2>&1; then
  ok "Deployment metrics-collector existe"
  kubectl -n team-beta get deploy metrics-collector -o jsonpath='{..securityContext.privileged}' | grep -q true \
    && fail "Deployment ainda tem container privilegiado" || ok "Deployment sem containers privilegiados"
  r=$(kubectl -n team-beta get deploy metrics-collector -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}/{.spec.replicas}')
  [ "$r" = "2/2/2" ] && ok "metrics-collector 2/2 réplicas prontas" || fail "metrics-collector não está com 2 réplicas prontas e atualizadas ($r)"
else
  fail "Deployment team-beta/metrics-collector foi deletado"
fi

priv=$(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.spec.containers[*].securityContext.privileged} {.spec.initContainers[*].securityContext.privileged}{"\n"}{end}' | grep -E '^team-(alpha|beta|gamma)/' | grep true)
[ -z "$priv" ] && ok "Nenhum Pod privilegiado restante em team-*" || fail "Ainda há Pods privilegiados: $priv"

finish
