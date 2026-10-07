#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

f=/opt/course/15/q2/admin-password.txt
[ -f $f ] && [ "$(tr -d '\n' < $f)" = 'L3g4cy-Adm!n-2019' ] && ok "admin-password correto" || fail "$f ausente ou incorreto (lembre de decodificar o base64)"

f=/opt/course/15/q2/sa-token.txt
if [ -s $f ]; then
  tok=$(tr -d '\n ' < $f)
  payload=$(echo "$tok" | cut -d. -f2 | tr '_-' '/+')
  while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
  sub=$(echo "$payload" | base64 -d 2>/dev/null | grep -o '"sub":"[^"]*"')
  [ "$sub" = '"sub":"system:serviceaccount:monitoring:agent-sa"' ] && ok "token pertence à SA monitoring/agent-sa" || fail "token em $f não é da SA agent-sa (sub=$sub)"
  pod_tok=$(kubectl -n monitoring exec agent -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
  if [ "$tok" = "$pod_tok" ]; then ok "token idêntico ao montado no Pod"; else
    pl=$(echo "$payload" | base64 -d 2>/dev/null)
    echo "$pl" | grep -q '"pod":{"name":"agent"' && ok "token é o token projetado do Pod agent (foi rotacionado desde então)" || fail "token não é o token projetado do Pod agent (use kubectl exec)"
  fi
else
  fail "$f ausente"
fi

f=/opt/course/15/q2/db-pass.txt
[ -f $f ] && [ "$(tr -d '\n' < $f)" = 'mon-store-7f3a:Pr0m-St0r3#42' ] && ok "db-pass.txt correto" || fail "$f ausente ou incorreto (formato <secret>:<valor>)"

finish
