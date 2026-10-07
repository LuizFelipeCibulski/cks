#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

flag() { ps -eo args | grep -E '^(/usr/local/bin/)?kube-apiserver ' | head -1 | tr ' ' '\n' | grep -- "^--$1=" | head -1 | cut -d= -f2-; }
LOG=/var/log/kubernetes/audit/audit.log

if kubectl get --raw=/readyz >/dev/null 2>&1; then ok "kube-apiserver respondendo"
else fail "kube-apiserver não está respondendo"; finish; fi

check_flag() {
  local v; v=$(flag "$1")
  if [ "$v" == "$2" ]; then ok "--$1=$2"; else fail "--$1 deveria ser '$2' (atual: '${v:-ausente}')"; fi
}
check_flag audit-policy-file /etc/kubernetes/audit/policy.yaml
check_flag audit-log-path /var/log/kubernetes/audit/audit.log
check_flag audit-log-maxage 7
check_flag audit-log-maxbackup 2
check_flag audit-log-maxsize 50

if [ -f /var/lib/cks-sim/23-q1.policy.sha256 ]; then
  [ "$(sha256sum /etc/kubernetes/audit/policy.yaml | awk '{print $1}')" == "$(cat /var/lib/cks-sim/23-q1.policy.sha256)" ] \
    && ok "policy não foi alterada" || fail "a policy foi alterada (não deveria)"
fi

# comportamento: uma criação de configmap deve aparecer no log do host em nível Metadata
kubectl delete cm cks-audit-q1 -n default --ignore-not-found >/dev/null 2>&1
kubectl create cm cks-audit-q1 -n default --from-literal=k=v >/dev/null 2>&1
sleep 3
if [ -s "$LOG" ]; then
  ok "audit log existe no host ($LOG)"
  line=$(grep '"cks-audit-q1"' "$LOG" | grep '"verb":"create"' | tail -1)
  if [ -n "$line" ]; then
    ok "criação do ConfigMap foi auditada"
    echo "$line" | grep -q '"level":"Metadata"' && ok "evento em nível Metadata (a policy está em uso)" || fail "evento não está em nível Metadata — a policy correta está em uso?"
  else
    fail "a criação do ConfigMap cks-audit-q1 não apareceu em $LOG"
  fi
else
  fail "$LOG não existe ou está vazio no host (volume hostPath montado?)"
fi
kubectl delete cm cks-audit-q1 -n default --ignore-not-found >/dev/null 2>&1

finish
