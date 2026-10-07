#!/usr/bin/env bash
# Node Metadata Protection — Q2 (Médio): verify
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=payments
NP=frontend-deny-metadata
META=http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role
EXT=http://198.51.100.10/
API=http://api.payments.svc.cluster.local/

can() { timeout 25 kubectl -n "$1" exec "$2" -- wget -T3 -qO- "$3" >/dev/null 2>&1; }
dns() { timeout 25 kubectl -n "$1" exec "$2" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; }
pods_of() { # pods ativos (sem deletionTimestamp) de um selector
  kubectl -n "$1" get pod -l "$2" -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}'
}

if ! can cks-probe probe "$META"; then
  fail "Ambiente: o pod de controle cks-probe/probe não alcança o metadata simulado. Rode 'bash setup.sh' novamente."
  finish
fi

if kubectl -n $NS get networkpolicy $NP >/dev/null 2>&1; then
  ok "NetworkPolicy $NS/$NP existe"
else
  fail "NetworkPolicy $NS/$NP não encontrada"
fi

TYPES=$(kubectl -n $NS get networkpolicy $NP -o jsonpath='{.spec.policyTypes}' 2>/dev/null)
if echo "$TYPES" | grep -q Ingress; then
  fail "a policy não deve restringir Ingress (policyTypes contém Ingress)"
fi

FRONTS=$(pods_of $NS tier=frontend)
BACK=$(pods_of $NS tier=backend | head -1)
[ -z "$FRONTS" ] && fail "nenhum pod do shop-frontend em Running"
[ -z "$BACK" ] && fail "pod do shop-backend não está em Running"

for p in $FRONTS; do
  if can $NS "$p" "$META"; then fail "frontend $p ainda acessa 169.254.169.254"; else ok "frontend $p NÃO acessa 169.254.169.254"; fi
  if dns $NS "$p"; then ok "frontend $p resolve DNS"; else fail "frontend $p não consegue resolver DNS (kubernetes.default.svc.cluster.local)"; fi
  if can $NS "$p" "$API"; then ok "frontend $p acessa o Service api"; else fail "frontend $p não acessa http://api.payments.svc.cluster.local"; fi
  if can $NS "$p" "$EXT"; then ok "frontend $p acessa o destino externo 198.51.100.10"; else fail "frontend $p perdeu acesso a 198.51.100.10"; fi
done

if [ -n "$BACK" ]; then
  if can $NS "$BACK" "$META"; then
    ok "backend $BACK continua acessando o metadata (não foi afetado)"
  else
    fail "backend $BACK perdeu acesso ao metadata — a policy deve selecionar SOMENTE o frontend"
  fi
  if can $NS "$BACK" "$API"; then ok "backend $BACK acessa o Service api"; else fail "backend $BACK não acessa o Service api"; fi
fi

finish
