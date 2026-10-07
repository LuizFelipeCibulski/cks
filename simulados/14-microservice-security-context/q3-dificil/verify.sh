#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

f=/opt/course/14/q3/violations.txt
exp="fin-a/audit-shipper fin-a/ledger fin-b/batch fin-b/cache fin-c/metrics fin-c/sidecar-app "
if [ -f $f ]; then
  got=$(tr -d ' \r' < $f | grep -v '^$' | sed -E 's#/(deployment|deploy|pod)/#/#; s#^(deployment|deploy|pod)/##' | sort -u | tr '\n' ' ')
  [ "$got" = "$exp" ] && ok "violations.txt correto" || fail "violations.txt incorreto. Encontrado: '$got'"
else
  fail "$f não existe"
fi

DEPLOYS="fin-a/ledger fin-a/audit-shipper fin-a/web fin-b/cache fin-b/batch fin-b/reporter fin-c/sidecar-app fin-c/api"
for d in $DEPLOYS; do
  ns=${d%/*}; n=${d#*/}
  if ! kubectl -n $ns get deploy $n >/dev/null 2>&1; then fail "Deployment $d não existe (não delete, edite)"; continue; fi
  r=$(kubectl -n $ns get deploy $n -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}/{.spec.replicas}')
  [ "$r" = "1/1/1" ] && ok "Deployment $d pronto" || fail "Deployment $d sem réplicas prontas/atualizadas ($r)"
  t=$(kubectl -n $ns get deploy $n -o jsonpath='{.spec.template.spec.hostPID} {.spec.template.spec.hostNetwork} {..securityContext.privileged}')
  echo "$t" | grep -q true && fail "Deployment $d ainda tem hostPID/hostNetwork/privileged ($t)" || ok "Deployment $d sem privileged/hostPID/hostNetwork"
done

# Pod avulso
st=$(kubectl -n fin-c get pod metrics -o jsonpath='{.status.phase} {.metadata.ownerReferences}' 2>/dev/null)
if [ "${st%% *}" = "Running" ] && ! echo "$st" | grep -q kind; then ok "Pod avulso fin-c/metrics recriado e Running"; else fail "Pod fin-c/metrics deve existir (avulso, mesmo nome) e estar Running"; fi
kubectl -n fin-c get pod metrics -o jsonpath='{.spec.containers[0].image} {.spec.containers[0].command}' 2>/dev/null | grep -q 'busybox:1.36.*sleep 1d' \
  && ok "metrics mantém imagem e comando" || fail "metrics deve manter imagem busybox:1.36 e comando sh -c 'sleep 1d'"

# Checagem de comportamento em TODOS os pods em execução dos 3 namespaces
bad=0
for ns in fin-a fin-b fin-c; do
  for p in $(kubectl -n $ns get pods --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.deletionTimestamp}{"\n"}{end}' 2>/dev/null | grep -E ':$' | tr -d ':'); do
    spec=$(kubectl -n $ns get pod $p -o jsonpath='{.spec.hostPID} {.spec.hostNetwork} {..securityContext.privileged}' 2>/dev/null)
    if echo "$spec" | grep -q true; then fail "Pod $ns/$p viola R1/R2/R3 ($spec)"; bad=1; fi
    for c in $(kubectl -n $ns get pod $p -o jsonpath='{.spec.containers[*].name}'); do
      u=$(kubectl -n $ns exec $p -c $c -- id -u 2>/dev/null)
      if [ "$u" = "0" ]; then fail "Container $ns/$p/$c roda como root (R4)"; bad=1; fi
    done
  done
done
[ $bad -eq 0 ] && ok "Nenhum Pod em execução viola R1–R4"

# Workloads que rodavam como root devem usar o UID 1000
for d in fin-a/ledger fin-b/batch; do
  ns=${d%/*}; n=${d#*/}
  u=$(kubectl -n $ns exec deploy/$n -- id -u 2>/dev/null)
  [ "$u" = "1000" ] && ok "$d roda com UID 1000" || fail "$d deveria rodar com UID 1000 (atual: '$u')"
done
u=$(kubectl -n fin-c exec metrics -- id -u 2>/dev/null)
[ "$u" = "1000" ] && ok "fin-c/metrics roda com UID 1000" || fail "fin-c/metrics deveria rodar com UID 1000 (atual: '$u')"

finish
