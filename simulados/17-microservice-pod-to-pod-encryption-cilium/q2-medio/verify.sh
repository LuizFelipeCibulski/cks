#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# Retorna stdout+stderr do wget e o exit code em $RC
wg() { # wg <pod> <args...>
  OUT=$(kubectl -n shop exec "$1" -- wget -T4 -qO- "${@:2}" 2>&1); RC=$?
}

# ---------- api-l7 ----------
if kubectl -n shop get cnp api-l7 >/dev/null 2>&1; then
  ok "CiliumNetworkPolicy shop/api-l7 existe"
  sel=$(kubectl -n shop get cnp api-l7 -o jsonpath='{.spec.endpointSelector.matchLabels.app}')
  [ "$sel" = "api" ] && ok "api-l7 seleciona app=api" || fail "api-l7 deve selecionar app=api"
  methods=$(kubectl -n shop get cnp api-l7 -o jsonpath='{.spec.ingress[*].toPorts[*].rules.http[*].method}')
  [ -n "$methods" ] && ok "api-l7 possui regras HTTP (L7)" || fail "api-l7 não possui regras L7 (toPorts[].rules.http)"
else
  fail "CiliumNetworkPolicy shop/api-l7 não encontrada"
fi

sleep 2
wg client http://api/public/
if [ $RC -eq 0 ] && echo "$OUT" | grep -q "catalogo publico"; then ok "client: GET /public/ permitido"; else fail "client: GET /public/ deveria funcionar (saída: $OUT)"; fi

wg client http://api/private/
if [ $RC -ne 0 ] && echo "$OUT" | grep -q "403"; then ok "client: GET /private/ negado pelo proxy L7 (403)"
elif [ $RC -ne 0 ]; then fail "client: GET /private/ falhou, mas não com 403 do Cilium (a negação deveria ser L7). Saída: $OUT"
else fail "client: GET /private/ NÃO deveria ser permitido"; fi

wg client --post-data=x http://api/public/
if [ $RC -ne 0 ] && echo "$OUT" | grep -q "403"; then ok "client: POST /public/ negado pelo proxy L7 (403)"
else fail "client: POST /public/ deveria ser negado com 403 pelo Cilium (saída: $OUT)"; fi

wg intruder http://api/public/
[ $RC -ne 0 ] && ok "intruder bloqueado" || fail "intruder NÃO deveria acessar a api"

# ---------- client-deny-world ----------
if kubectl -n shop get cnp client-deny-world >/dev/null 2>&1; then
  ok "CiliumNetworkPolicy shop/client-deny-world existe"
  sel=$(kubectl -n shop get cnp client-deny-world -o jsonpath='{.spec.endpointSelector.matchLabels.app}')
  [ "$sel" = "client" ] && ok "client-deny-world seleciona app=client" || fail "client-deny-world deve selecionar app=client"
  ents=$(kubectl -n shop get cnp client-deny-world -o jsonpath='{.spec.egressDeny[*].toEntities[*]}')
  echo "$ents" | grep -qw world && ok "egressDeny com toEntities: world" || fail "client-deny-world deve usar egressDeny com toEntities [world]"
else
  fail "CiliumNetworkPolicy shop/client-deny-world não encontrada"
fi

# DNS + acesso à api continuam funcionando (já testado acima via nome 'api')
kubectl -n shop exec client -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 \
  && ok "client resolve DNS" || fail "client não resolve DNS (a deny/allow de egress quebrou o DNS?)"

# Teste de saída para a internet (só se o host tiver internet)
if curl -s -m5 -o /dev/null http://1.1.1.1 2>/dev/null; then
  OUT=$(kubectl -n shop exec client -- wget -T4 -O /dev/null http://1.1.1.1 2>&1)
  if echo "$OUT" | grep -qi "timed out"; then ok "client não alcança a internet (world)"
  else fail "client ainda alcança a internet (saída: $(echo "$OUT" | tail -1))"; fi
else
  info "Host sem acesso à internet: teste comportamental de 'world' ignorado"
fi

finish
