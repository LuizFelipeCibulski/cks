#!/usr/bin/env bash
# Network Policies — Q2 (Médio): verificação
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

reach() { timeout 15 kubectl -n "$1" exec "$2" -- wget -qO- -T 3 "$3" 2>/dev/null | grep -q .; }
dns()   { timeout 20 kubectl -n "$1" exec "$2" -- nslookup "$3" 2>/dev/null | grep -qi "^name:"; }

GW=http://gateway.payments.svc.cluster.local
LEDGER=http://ledger.payments.svc.cluster.local
GW_IP=$(kubectl -n payments get pod gateway -o jsonpath='{.status.podIP}')

# Existência e seleção dos Pods
for spec in payments/gateway-ingress orders/api-egress; do
  ns=${spec%/*}; np=${spec#*/}
  if kubectl -n "$ns" get networkpolicy "$np" >/dev/null 2>&1; then ok "NetworkPolicy $ns/$np existe"; else fail "NetworkPolicy $ns/$np não existe"; fi
done

sel=$(kubectl -n payments get networkpolicy gateway-ingress -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
[ "$sel" = "gateway" ] && ok "gateway-ingress seleciona app=gateway" || fail "gateway-ingress deveria selecionar podSelector app=gateway"
sel=$(kubectl -n orders get networkpolicy api-egress -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null)
[ "$sel" = "api" ] && ok "api-egress seleciona app=api" || fail "api-egress deveria selecionar podSelector app=api"
types=$(kubectl -n orders get networkpolicy api-egress -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null)
[[ " $types " == *" Egress "* ]] && ok "api-egress tem policyTypes Egress" || fail "api-egress precisa de policyTypes: [Egress]"

# Comportamento
if dns orders api kubernetes.default.svc.cluster.local; then ok "orders/api resolve DNS"; else fail "orders/api não resolve DNS (liberou 53 UDP/TCP para kube-dns?)"; fi
if reach orders api "$GW"; then ok "orders/api acessa gateway por nome"; else fail "orders/api NÃO acessa $GW"; fi
if reach orders worker "http://$GW_IP"; then fail "orders/worker ainda acessa o gateway"; else ok "orders/worker bloqueado no gateway"; fi
if reach sandbox api "http://$GW_IP"; then fail "sandbox/api (app=api em outro namespace) acessa o gateway — regra OR em vez de AND?"; else ok "sandbox/api bloqueado no gateway (namespaceSelector AND podSelector)"; fi
if reach orders api "$LEDGER"; then fail "orders/api ainda acessa o ledger (egress aberto demais)"; else ok "orders/api bloqueado no ledger"; fi
if reach orders worker "$LEDGER"; then ok "orders/worker continua acessando o ledger (não afetado)"; else fail "orders/worker não acessa ledger — as políticas afetaram Pods que não deveriam"; fi
if reach sandbox api "$LEDGER"; then ok "ledger continua aberto para outros namespaces"; else fail "ledger foi bloqueado — gateway-ingress não deveria afetá-lo"; fi

finish
