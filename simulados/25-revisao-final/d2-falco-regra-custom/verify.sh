#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

SVC=$(falco_svc)
systemctl is-active --quiet "$SVC" && ok "Falco ativo" || fail "Falco não está ativo"

L=/etc/falco/falco_rules.local.yaml
block=$(awk '/^- rule: *"?Package management in container/{f=1; print; next} f && /^- (rule|macro|list):/{f=0} f' "$L")
if [ -n "$block" ]; then
  ok "regra encontrada"
  echo "$block" | grep -Eqi 'priority: *ERROR' && ok "prioridade ERROR" || fail "prioridade deve ser ERROR"
  echo "$block" | grep -Fq '%evt.time,%container.id,%container.image.repository,%proc.name' \
    && ok "output correto" || fail "output diferente do pedido"
else
  fail "regra 'Package management in container' não está em $L"
fi

F=/opt/course/25/d2/falco.log
grep -Eq ',[0-9a-f]{12},[^,]*,(apk|apt-get)' "$F" 2>/dev/null && ok "falco.log contém alertas da regra" || fail "$F sem alertas no formato pedido"

r() { kubectl -n "$1" get deploy "$2" -o jsonpath='{.spec.replicas}' 2>/dev/null; }
for d in store/reports legacy/importer; do
  v=$(r ${d%/*} ${d#*/}); [ "$v" = "0" ] && ok "$d escalado para 0" || fail "$d deveria estar com 0 réplicas (atual: ${v:-apagado})"
done
declare -A ORIG=([store/catalog]=2 [store/updater]=1 [legacy/scheduler]=1)
for d in "${!ORIG[@]}"; do
  v=$(r ${d%/*} ${d#*/}); [ "$v" = "${ORIG[$d]}" ] && ok "$d inalterado" || fail "$d foi alterado (réplicas: ${v:-apagado})"
done

got=$(sed 's/[[:space:]]//g; s#deployment.apps/##; s#deploy/##' /opt/course/25/d2/report.txt 2>/dev/null | grep -v '^$' | sort -u | tr '\n' ' ')
[ "$got" = "legacy/importer store/reports " ] && ok "report.txt correto" || fail "report.txt incorreto: '$got'"
finish
