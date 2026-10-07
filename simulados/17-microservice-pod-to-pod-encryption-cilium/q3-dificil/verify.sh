#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# 1) WireGuard persistido na config
wg=$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')
[ "$wg" = "true" ] && ok "cilium-config: enable-wireguard=true" || fail "cilium-config: enable-wireguard deveria ser \"true\" (atual: '$wg')"

# DaemonSet do Cilium saudável
des=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}')
rdy=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.numberReady}')
upd=$(kubectl -n kube-system get ds cilium -o jsonpath='{.status.updatedNumberScheduled}')
[ -n "$des" ] && [ "$des" = "$rdy" ] && [ "$des" = "$upd" ] && ok "DaemonSet cilium: $rdy/$des prontos e atualizados" || fail "DaemonSet cilium não está totalmente pronto ($rdy/$des, updated=$upd)"

# 1b) Ativo em todos os agentes
all_ok=1
for p in $(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[*].metadata.name}'); do
  st=$(kubectl -n kube-system exec "$p" -c cilium-agent -- cilium-dbg encrypt status 2>/dev/null \
       || kubectl -n kube-system exec "$p" -c cilium-agent -- cilium encrypt status 2>/dev/null)
  if echo "$st" | grep -qi wireguard; then :; else all_ok=0; echo "   agente $p: $(echo "$st" | head -1)"; fi
done
[ $all_ok -eq 1 ] && ok "Todos os agentes Cilium reportam Encryption: Wireguard" || fail "Nem todos os agentes Cilium estão com WireGuard ativo (reiniciou os pods do cilium?)"

ip link show cilium_wg0 >/dev/null 2>&1 && ok "Interface cilium_wg0 presente no controlplane" || fail "Interface cilium_wg0 não existe no controlplane"

# 2) Arquivo de status
f=/opt/course/17/encrypt-status.txt
if [ -s "$f" ] && grep -qi wireguard "$f"; then ok "$f contém o status de criptografia (Wireguard)"
else fail "$f ausente ou sem 'Wireguard'"; fi

# 3) Política e comportamento
kubectl -n secure-payments get cnp payment-api-ingress >/dev/null 2>&1 \
  && ok "CNP secure-payments/payment-api-ingress existe" || fail "CNP secure-payments/payment-api-ingress não encontrada"

sleep 2
kubectl -n secure-payments exec payment-client -- wget -qO- -T4 http://payment-api:8080 >/dev/null 2>&1 \
  && ok "payment-client acessa payment-api:8080" || fail "payment-client deveria acessar payment-api:8080"
kubectl -n secure-payments exec attacker -- wget -qO- -T4 http://payment-api:8080 >/dev/null 2>&1 \
  && fail "attacker ainda acessa payment-api (há alguma política permitindo além da sua?)" || ok "attacker bloqueado"

# 4) Manifesto de mutual auth
m=/opt/course/17/mutual-auth.yaml
if [ -s "$m" ]; then
  if J=$(kubectl create --dry-run=server -o json -f "$m" 2>/tmp/ma.err); then
    ok "mutual-auth.yaml válido no API server (dry-run=server)"
    kind=$(echo "$J" | jq -r '.kind'); name=$(echo "$J" | jq -r '.metadata.name'); ns=$(echo "$J" | jq -r '.metadata.namespace')
    [ "$kind" = "CiliumNetworkPolicy" ] && [ "$name" = "payment-api-mutual-auth" ] && [ "$ns" = "secure-payments" ] \
      && ok "kind/nome/namespace corretos" || fail "esperado CiliumNetworkPolicy secure-payments/payment-api-mutual-auth (achado: $kind $ns/$name)"
    mode=$(echo "$J" | jq -r '[.spec.ingress[]?.authentication.mode] | join(",")')
    echo "$mode" | grep -q required && ok "ingress com authentication.mode: required" || fail "regra de ingress deve ter authentication.mode: required"
    echo "$J" | jq -e '.spec.endpointSelector.matchLabels.app=="payment-api"' >/dev/null \
      && ok "mutual-auth seleciona app=payment-api" || fail "mutual-auth deve selecionar app=payment-api"
  else
    fail "mutual-auth.yaml rejeitado pelo API server: $(tail -1 /tmp/ma.err)"
  fi
else
  fail "$m não encontrado"
fi
kubectl -n secure-payments get cnp payment-api-mutual-auth >/dev/null 2>&1 \
  && fail "payment-api-mutual-auth NÃO deveria estar aplicada no cluster" || ok "payment-api-mutual-auth não aplicada (correto)"

finish
