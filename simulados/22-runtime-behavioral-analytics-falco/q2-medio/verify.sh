#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

replicas() { kubectl -n "$1" get deploy "$2" -o jsonpath='{.spec.replicas}' 2>/dev/null; }

for d in billing/invoice analytics/collector; do
  ns=${d%/*}; n=${d#*/}
  r=$(replicas "$ns" "$n")
  if [ -z "$r" ]; then fail "Deployment $d foi apagado (deveria ser escalado para 0)"
  elif [ "$r" == "0" ]; then ok "$d escalado para 0"
  else fail "$d ainda tem $r réplica(s)"; fi
done

declare -A ORIG=([shop/frontend]=2 [shop/cart]=1 [billing/payments]=2 [analytics/reporter]=1)
for d in "${!ORIG[@]}"; do
  ns=${d%/*}; n=${d#*/}
  r=$(replicas "$ns" "$n")
  ready=$(kubectl -n "$ns" get deploy "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "$r" == "${ORIG[$d]}" ] && [ "${ready:-0}" == "${ORIG[$d]}" ]; then ok "$d inalterado e rodando"
  else fail "$d foi alterado ou não está pronto (replicas=$r ready=${ready:-0})"; fi
done

F=/opt/course/22/q2/report.txt
if [ -f "$F" ]; then
  got=$(sed 's/#.*//; s/[[:space:]]//g; s#deployment\.apps/##; s#deploy/##' "$F" | grep -v '^$' | sort -u)
  want=$(printf 'analytics/collector\nbilling/invoice')
  [ "$got" == "$want" ] && ok "report.txt correto" || fail "report.txt incorreto: $(echo $got)"
else
  fail "$F não existe"
fi

finish
