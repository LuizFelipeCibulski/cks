#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

kubectl get --raw=/readyz >/dev/null 2>&1 && ok "kube-apiserver respondendo" || { fail "kube-apiserver fora do ar"; finish; }

grep -q -- '--enable-admission-plugins=.*NodeRestriction' "$MANIFEST" && ok "--enable-admission-plugins com NodeRestriction" || fail "flag --enable-admission-plugins/NodeRestriction ausente"
grep -q -- '--enable-admission-plugin=' "$MANIFEST" && fail "flag inválida --enable-admission-plugin ainda existe"
for f in "audit-policy-file=/etc/kubernetes/audit/policy.yaml" "audit-log-path=/var/log/kubernetes/audit/audit.log" \
         "audit-log-maxbackup=2" "audit-log-maxage=5" "audit-log-maxsize=50"; do
  grep -q -- "--$f\b" "$MANIFEST" && ok "--$f" || fail "flag --$f ausente/incorreta"
done

LOG=/var/log/kubernetes/audit/audit.log
N=v$RANDOM
kubectl -n d5 create secret generic s-$N --from-literal=k=v >/dev/null
kubectl -n d5 get secret s-$N >/dev/null
kubectl -n d5 create configmap c-$N --from-literal=k=v >/dev/null
kubectl -n d5 get configmap c-$N >/dev/null
kubectl -n default create configmap c-$N --from-literal=k=v >/dev/null
kubectl -n default get configmap c-$N >/dev/null
kubectl -n default create secret generic s-$N --from-literal=k=v >/dev/null
kubectl -n default get secret s-$N >/dev/null
sleep 4

if [ -s "$LOG" ]; then
  ok "$LOG existe no host"
  lvl() { grep -F "\"requestURI\":\"$1\"" "$LOG" | grep -o '"level":"[A-Za-z]*"' | sort -u | tr -d '\n'; }
  [ "$(lvl /api/v1/namespaces/d5/secrets/s-$N)" = '"level":"Metadata"' ] && ok "secret em d5 → Metadata" || fail "secret em d5 deveria ser Metadata (achado: $(lvl /api/v1/namespaces/d5/secrets/s-$N))"
  [ "$(lvl /api/v1/namespaces/default/secrets/s-$N)" = '"level":"Metadata"' ] && ok "secret em default → Metadata" || fail "secret em default deveria ser Metadata"
  [ "$(lvl /api/v1/namespaces/d5/configmaps/c-$N)" = '"level":"RequestResponse"' ] && ok "configmap em d5 → RequestResponse" || fail "configmap em d5 deveria ser RequestResponse"
  [ -z "$(lvl /api/v1/namespaces/default/configmaps/c-$N)" ] && ok "configmap em default não logado" || fail "configmap em default NÃO deveria ser logado"
  grep -q '"stage":"RequestReceived"' "$LOG" && fail "há eventos RequestReceived no log" || ok "sem eventos RequestReceived"
else
  fail "$LOG vazio ou inexistente no host (volumes/volumeMounts?)"
fi
kubectl -n default delete cm c-$N >/dev/null 2>&1; kubectl -n default delete secret s-$N >/dev/null 2>&1
finish
