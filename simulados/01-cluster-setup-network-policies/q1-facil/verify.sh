#!/usr/bin/env bash
# Network Policies — Q1 (Fácil): verificação
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# reach <ns> <pod> <url>  -> 0 se conseguiu baixar a página
reach() { timeout 15 kubectl -n "$1" exec "$2" -- wget -qO- -T 3 "$3" >/dev/null 2>&1; }
podip() { kubectl -n "$1" get pod "$2" -o jsonpath='{.status.podIP}'; }

NP=default-deny
if ! kubectl -n restricted get networkpolicy "$NP" >/dev/null 2>&1; then
  fail "NetworkPolicy $NP não existe no namespace restricted"
  finish
fi
ok "NetworkPolicy $NP existe"

sel=$(kubectl -n restricted get networkpolicy "$NP" -o jsonpath='{.spec.podSelector}')
if [ -z "$sel" ] || [ "$sel" = "{}" ]; then ok "podSelector seleciona todos os Pods"; else fail "podSelector deveria ser {} (todos os Pods), está: $sel"; fi

types=$(kubectl -n restricted get networkpolicy "$NP" -o jsonpath='{.spec.policyTypes[*]}')
[[ " $types " == *" Ingress "* ]] && ok "policyTypes contém Ingress" || fail "policyTypes não contém Ingress"
[[ " $types " == *" Egress "* ]]  && ok "policyTypes contém Egress"  || fail "policyTypes não contém Egress"

rules=$(kubectl -n restricted get networkpolicy "$NP" -o jsonpath='{.spec.ingress}{.spec.egress}' | sed 's/\[\]//g')
[ -z "$rules" ] && ok "Sem regras de allow (deny total)" || fail "A policy $NP não deveria ter regras ingress/egress: $rules"

# Testes de comportamento
PROBE_IP=$(podip cks-probe probe)
APP1_IP=$(podip restricted app1)
APP2_IP=$(podip restricted app2)

if reach cks-probe probe "http://$PROBE_IP"; then ok "Sanidade: probe alcança a si mesmo"; else fail "Sanidade: probe não responde (ambiente quebrado? rode setup.sh de novo)"; fi
if reach cks-probe probe "http://$APP1_IP"; then fail "cks-probe/probe ainda alcança restricted/app1 (ingress não bloqueado)"; else ok "Ingress para restricted/app1 bloqueado"; fi
if reach restricted app1 "http://$APP2_IP"; then fail "app1 ainda alcança app2 dentro de restricted"; else ok "Tráfego interno do namespace bloqueado"; fi
if reach restricted app2 "http://$PROBE_IP"; then fail "restricted/app2 ainda alcança cks-probe/probe (egress não bloqueado)"; else ok "Egress de restricted bloqueado"; fi

# Arquivo de resposta
F=/opt/course/netpol/q1/default-deny.yaml
if [ -s "$F" ] && grep -q 'kind: *NetworkPolicy' "$F" && grep -q "$NP" "$F"; then
  ok "Manifesto salvo em $F"
else
  fail "Manifesto não encontrado/inválido em $F"
fi

finish
