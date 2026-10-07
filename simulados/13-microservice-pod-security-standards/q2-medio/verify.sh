#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

lbl() { kubectl get ns "$1" -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$2}" 2>/dev/null; }
chk() { # ns chave valor
  [ "$(lbl "$1" "$2")" = "$3" ] && ok "$1: $2=$3" || fail "$1: label pod-security.kubernetes.io/$2 deveria ser '$3' (atual: '$(lbl "$1" "$2")')"
}

chk apps-prod enforce restricted
chk apps-prod enforce-version v1.34
chk apps-prod warn restricted
chk apps-prod warn-version latest
chk apps-prod audit restricted
chk apps-prod audit-version latest
chk apps-dev enforce baseline
chk apps-dev enforce-version latest
chk apps-dev warn restricted
chk apps-dev warn-version latest

f=/opt/course/13/q2/violations.txt
if [ -f $f ]; then
  got=$(tr -d ' \r' < $f | sed 's#^pod/##; s#^apps-prod/##' | grep -v '^$' | sort -u | tr '\n' ' ')
  exp="backend cache debug "
  [ "$got" = "$exp" ] && ok "violations.txt correto" || fail "violations.txt incorreto (conteúdo: '$got')"
else
  fail "$f não existe"
fi

for p in backend cache debug; do
  kubectl -n apps-prod get pod $p >/dev/null 2>&1 && fail "Pod violador apps-prod/$p ainda existe" || ok "Pod apps-prod/$p removido"
done
for p in frontend metrics; do
  [ "$(kubectl -n apps-prod get pod $p -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] && ok "Pod compatível apps-prod/$p rodando" || fail "Pod apps-prod/$p deveria continuar Running"
done

# Comportamento
out=$(kubectl -n apps-prod run psa-probe --image=busybox:1.36 --dry-run=server -- sleep 1 2>&1)
echo "$out" | grep -q "violates PodSecurity \"restricted:v1.34\"" && ok "apps-prod rejeita pod não-restricted (restricted:v1.34)" || fail "apps-prod não rejeitou um pod comum com restricted:v1.34"
out=$(kubectl -n apps-dev run psa-probe --image=busybox:1.36 --dry-run=server -- sleep 1 2>&1)
if echo "$out" | grep -q "created (server dry run)" && echo "$out" | grep -q "would violate PodSecurity \"restricted:latest\""; then
  ok "apps-dev aceita pod baseline e avisa sobre restricted"
else fail "apps-dev: esperado aceitar pod comum com warning restricted (saída: $out)"; fi
out=$(kubectl -n apps-dev run psa-probe --image=busybox:1.36 --dry-run=server --overrides='{"spec":{"hostPID":true}}' -- sleep 1 2>&1)
echo "$out" | grep -q "violates PodSecurity \"baseline:latest\"" && ok "apps-dev rejeita hostPID (baseline)" || fail "apps-dev não rejeitou pod com hostPID"

finish
