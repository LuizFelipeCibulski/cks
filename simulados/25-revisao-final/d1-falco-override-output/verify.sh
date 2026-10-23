#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

SVC=$(falco_svc)
systemctl is-active --quiet "$SVC" && ok "Falco ($SVC) ativo" || fail "Falco ($SVC) não está ativo: journalctl -u $SVC -n 30"

sha256sum --quiet -c /root/cks-backup/d1-falco_rules.sha256 >/dev/null 2>&1 \
  && ok "/etc/falco/falco_rules.yaml intacto" || fail "/etc/falco/falco_rules.yaml foi alterado (use falco_rules.local.yaml)"

grep -Eq 'rule: *"?Terminal shell in container' /etc/falco/falco_rules.local.yaml \
  && ok "regra sobrescrita em falco_rules.local.yaml" || fail "regra 'Terminal shell in container' não está em falco_rules.local.yaml"

F=/var/log/falco/alerts.log
before=$(wc -l < "$F" 2>/dev/null || echo 0)
# dispara um shell com TTY no container
script -qc "kubectl -n d1 exec -it webshell -- sh -c 'sleep 1'" /dev/null >/dev/null 2>&1
sleep 5
if [ -f "$F" ]; then
  new=$(tail -n +$((before+1)) "$F")
  if echo "$new" | grep -E 'Critical' | grep -Eq '[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+,[0-9a-f]{12},root,sh'; then
    ok "alerta no formato correto em $F"
  else
    fail "nenhum alerta Critical no formato esperado em $F. Últimas linhas:"; echo "$new" | tail -3
  fi
else
  fail "$F não existe (file_output habilitado? diretório existe?)"
fi
finish
