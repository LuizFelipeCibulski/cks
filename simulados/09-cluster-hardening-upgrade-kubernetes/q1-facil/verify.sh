#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

OUT=/opt/course/09/q1
W=$(worker_node)

# 1. versão atual
CUR=$(kubectl get --raw /version 2>/dev/null | tr ',{}' '\n\n\n' | grep '"gitVersion"' | sed -E 's/.*"(v[^"]+)".*/\1/')
ANS=$(tr -d '[:space:]' < "$OUT/current-version.txt" 2>/dev/null)
[ -n "$ANS" ] && [ "${ANS#v}" = "${CUR#v}" ] \
  && ok "current-version.txt correto ($CUR)" \
  || fail "current-version.txt deveria conter $CUR (encontrado: '${ANS:-vazio}')"

# 2. plano de upgrade
if [ -s "$OUT/plan.txt" ] && grep -Eqi 'upgrade/versions|cluster version|kubeadm upgrade apply|up-to-date|COMPONENT' "$OUT/plan.txt"; then
  ok "plan.txt contém a saída do kubeadm upgrade plan"
else
  fail "plan.txt vazio ou não parece ser a saída de 'kubeadm upgrade plan'"
fi

# 3. versão mais nova do kubeadm no repo
LATEST=$(apt-cache madison kubeadm 2>/dev/null | awk '{print $3}' | sort -V | tail -1)
ANS=$(tr -d '[:space:]' < "$OUT/latest.txt" 2>/dev/null)
if [ -z "$LATEST" ]; then
  fail "não foi possível consultar o apt (apt-cache madison kubeadm vazio)"
elif [ "$ANS" = "$LATEST" ] || [ "$ANS" = "${LATEST%%-*}" ]; then
  ok "latest.txt correto ($LATEST)"
else
  fail "latest.txt deveria conter $LATEST (encontrado: '${ANS:-vazio}')"
fi

# 4. node01 em manutenção
if [ -z "$W" ]; then
  ok "cluster sem node worker — item 4 ignorado"
else
  [ "$(kubectl get node "$W" -o jsonpath='{.spec.unschedulable}')" = "true" ] \
    && ok "$W está cordoned (SchedulingDisabled)" \
    || fail "$W ainda aceita novos pods"
  LEFT=$(kubectl get pods -A --field-selector spec.nodeName="$W" \
    -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} {.metadata.ownerReferences[0].kind} {.status.phase}{"\n"}{end}' \
    | awk '$2!="DaemonSet" && $2!="Node" && ($3=="Running" || $3=="Pending") {print $1}')
  [ -z "$LEFT" ] \
    && ok "nenhum pod de workload restante em $W" \
    || fail "ainda há pods de workload em $W: $(echo $LEFT)"
  kubectl get node "$W" >/dev/null 2>&1 && ok "$W continua registrado no cluster" || fail "$W foi removido do cluster"
fi

finish
