#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

SA=system:serviceaccount:finance:report-bot
can() { [ "$(kubectl auth can-i "$@" 2>/dev/null)" = "yes" ]; }

kubectl -n finance get role pod-reader >/dev/null 2>&1 && ok "Role pod-reader existe" || fail "Role pod-reader não existe em finance"

RB_REF=$(kubectl -n finance get rolebinding report-bot-pod-reader -o jsonpath='{.roleRef.kind}/{.roleRef.name}' 2>/dev/null)
[ "$RB_REF" = "Role/pod-reader" ] && ok "RoleBinding report-bot-pod-reader aponta para Role/pod-reader" \
  || fail "RoleBinding report-bot-pod-reader ausente ou com roleRef errado ($RB_REF)"
SUBJ=$(kubectl -n finance get rolebinding report-bot-pod-reader -o jsonpath='{range .subjects[*]}{.kind}:{.namespace}:{.name}{"\n"}{end}' 2>/dev/null)
echo "$SUBJ" | grep -qx 'ServiceAccount:finance:report-bot' && ok "RoleBinding tem a SA report-bot como subject" \
  || fail "RoleBinding não referencia ServiceAccount finance/report-bot"

for v in get list watch; do
  can "$v" pods -n finance --as "$SA" && ok "report-bot pode $v pods em finance" || fail "report-bot NÃO pode $v pods em finance"
done
can delete pods -n finance --as "$SA" && fail "report-bot pode deletar pods (excesso)" || ok "report-bot não pode deletar pods"
can create pods -n finance --as "$SA" && fail "report-bot pode criar pods (excesso)" || ok "report-bot não pode criar pods"
can get secrets -n finance --as "$SA" && fail "report-bot pode ler secrets (excesso)" || ok "report-bot não pode ler secrets"
can list pods -n default --as "$SA" && fail "report-bot pode listar pods em default" || ok "report-bot não lista pods fora de finance"

finish
