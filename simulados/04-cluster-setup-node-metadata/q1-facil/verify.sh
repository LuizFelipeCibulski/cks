#!/usr/bin/env bash
# Node Metadata Protection — Q1 (Fácil): verify
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=cloud-app
META=http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role
EXT=http://198.51.100.10/

can() { timeout 20 kubectl -n "$1" exec "$2" -- wget -T3 -qO- "$3" >/dev/null 2>&1; }

# 0) Sanidade do ambiente simulado (pod sem nenhuma NetworkPolicy)
if ! can cks-probe probe "$META"; then
  fail "Ambiente: o pod de controle cks-probe/probe não alcança o metadata simulado. Rode 'bash setup.sh' novamente."
  finish
fi

# 1) A policy existe
if kubectl -n $NS get networkpolicy deny-metadata >/dev/null 2>&1; then
  ok "NetworkPolicy $NS/deny-metadata existe"
else
  fail "NetworkPolicy $NS/deny-metadata não encontrada"
fi

# 2) Seleciona todos os pods do namespace
SEL=$(kubectl -n $NS get networkpolicy deny-metadata -o jsonpath='{.spec.podSelector.matchLabels}{.spec.podSelector.matchExpressions}' 2>/dev/null)
if kubectl -n $NS get networkpolicy deny-metadata >/dev/null 2>&1 && [ -z "$SEL" ]; then
  ok "podSelector vazio (todos os pods de $NS)"
else
  fail "a policy deve selecionar TODOS os pods do namespace (podSelector: {})"
fi

# 3) Comportamento: metadata bloqueado para os dois pods
for p in web worker; do
  if can $NS $p "$META"; then
    fail "pod $NS/$p ainda acessa 169.254.169.254"
  else
    ok "pod $NS/$p NÃO acessa 169.254.169.254"
  fi
done

# 4) Comportamento: resto do egress externo continua liberado
for p in web worker; do
  if can $NS $p "$EXT"; then
    ok "pod $NS/$p ainda acessa o destino externo 198.51.100.10"
  else
    fail "pod $NS/$p perdeu acesso ao destino externo 198.51.100.10 (o resto do egress deve continuar liberado)"
  fi
done

# 5) Ingress não deve ter sido restringido
WEBIP=$(kubectl -n $NS get pod web -o jsonpath='{.status.podIP}')
if [ -n "$WEBIP" ] && can cks-probe probe "http://$WEBIP/"; then
  ok "ingress para $NS/web continua funcionando"
else
  fail "o tráfego de entrada (ingress) para $NS/web foi bloqueado — a tarefa é só de egress"
fi

finish
