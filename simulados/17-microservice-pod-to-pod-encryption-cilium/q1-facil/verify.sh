#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

reach() { # reach <ns> <pod> <url>
  kubectl -n "$1" exec "$2" -- wget -qO- -T3 "$3" >/dev/null 2>&1
}

if kubectl -n team-blue get ciliumnetworkpolicy backend-ingress >/dev/null 2>&1; then
  ok "CiliumNetworkPolicy team-blue/backend-ingress existe"
else
  fail "CiliumNetworkPolicy team-blue/backend-ingress não encontrada"
  finish
fi

sel=$(kubectl -n team-blue get cnp backend-ingress -o jsonpath='{.spec.endpointSelector.matchLabels.app}')
[ "$sel" = "backend" ] && ok "endpointSelector seleciona app=backend" || fail "endpointSelector deve selecionar app=backend (encontrado: '$sel')"

ports=$(kubectl -n team-blue get cnp backend-ingress -o jsonpath='{.spec.ingress[*].toPorts[*].ports[*].port}')
echo "$ports" | grep -qw 80 && ok "Regra de ingress restringe à porta 80" || fail "Regra de ingress deve ter toPorts com a porta 80"

if kubectl get networkpolicy -n team-blue --no-headers 2>/dev/null | grep -q .; then
  fail "Existe NetworkPolicy (networking.k8s.io) em team-blue — use apenas CiliumNetworkPolicy"
fi

sleep 2
reach team-blue frontend http://backend.team-blue.svc.cluster.local \
  && ok "team-blue/frontend acessa backend:80" \
  || fail "team-blue/frontend deveria acessar backend:80"

reach team-blue other http://backend.team-blue.svc.cluster.local \
  && fail "team-blue/other NÃO deveria acessar backend" \
  || ok "team-blue/other bloqueado"

reach team-green frontend http://backend.team-blue.svc.cluster.local \
  && fail "team-green/frontend NÃO deveria acessar backend (namespace diferente)" \
  || ok "team-green/frontend bloqueado"

finish
