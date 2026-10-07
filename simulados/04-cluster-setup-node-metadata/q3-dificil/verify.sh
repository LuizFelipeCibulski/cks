#!/usr/bin/env bash
# Node Metadata Protection — Q3 (Difícil): verify
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=ml-platform
META=http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role
EXT=http://198.51.100.10/
STORE=http://model-store.storage.svc.cluster.local/

can() { timeout 25 kubectl -n "$1" exec "$2" -- wget -T3 -qO- "$3" >/dev/null 2>&1; }
dns() { timeout 25 kubectl -n "$1" exec "$2" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; }
pods_of() { # pods ativos (Running, sem deletionTimestamp) de um selector
  kubectl -n "$1" get pod -l "$2" -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}'
}
jp() { kubectl -n "$1" get "$2" -o jsonpath="$3" 2>/dev/null; }

if ! can cks-probe probe "$META"; then
  fail "Ambiente: o pod de controle cks-probe/probe não alcança o metadata simulado. Rode 'bash setup.sh' novamente."
  finish
fi

# ---------- compliance: default-deny-egress intacta ----------
if kubectl -n $NS get networkpolicy default-deny-egress >/dev/null 2>&1 \
   && [ -z "$(jp $NS networkpolicy/default-deny-egress '{.spec.podSelector.matchLabels}{.spec.podSelector.matchExpressions}{.spec.egress}')" ] \
   && jp $NS networkpolicy/default-deny-egress '{.spec.policyTypes}' | grep -q Egress; then
  ok "default-deny-egress continua existindo e sem alterações"
else
  fail "a NetworkPolicy default-deny-egress foi removida ou alterada (requisito de compliance)"
fi

# ---------- policies do namespace storage intactas ----------
if jp storage networkpolicy/model-store-ingress '{.spec.ingress[*].from[*].namespaceSelector.matchLabels}' | grep -q '"team":"ml"'; then
  ok "NetworkPolicy storage/model-store-ingress não foi alterada"
else
  fail "storage/model-store-ingress foi removida/alterada (não altere o namespace storage)"
fi

# ---------- allow-metadata-accessor ----------
if kubectl -n $NS get networkpolicy allow-metadata-accessor >/dev/null 2>&1; then
  ok "NetworkPolicy allow-metadata-accessor existe"
  ROLE=$(jp $NS networkpolicy/allow-metadata-accessor '{.spec.podSelector.matchLabels.role}')
  [ "$ROLE" = "metadata-accessor" ] && ok "allow-metadata-accessor seleciona role=metadata-accessor" \
    || fail "allow-metadata-accessor deve selecionar pods com label role=metadata-accessor (podSelector.matchLabels)"
  CIDRS=$(jp $NS networkpolicy/allow-metadata-accessor '{.spec.egress[*].to[*].ipBlock.cidr}')
  if [ "$CIDRS" = "169.254.169.254/32" ]; then
    ok "allow-metadata-accessor libera apenas 169.254.169.254/32"
  else
    fail "allow-metadata-accessor deve liberar somente o ipBlock 169.254.169.254/32 (encontrado: '${CIDRS}')"
  fi
  PORTS=$(jp $NS networkpolicy/allow-metadata-accessor '{.spec.egress[*].ports[*].port}')
  [ "$PORTS" = "80" ] && ok "allow-metadata-accessor restringe à porta 80" \
    || fail "allow-metadata-accessor deve permitir apenas TCP 80 (encontrado: '${PORTS}')"
else
  fail "NetworkPolicy $NS/allow-metadata-accessor não encontrada"
fi

# ---------- labels ----------
TPL=$(jp $NS deploy/cloud-sync '{.spec.template.metadata.labels.role}')
[ "$TPL" = "metadata-accessor" ] && ok "template do Deployment cloud-sync tem role=metadata-accessor" \
  || fail "o pod template do Deployment cloud-sync deve ter o label role=metadata-accessor"
kubectl -n $NS rollout status deploy/cloud-sync --timeout=90s >/dev/null 2>&1

WRONG=$(kubectl -n $NS get pod -l role=metadata-accessor -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{if ne (index .metadata.labels "app") "cloud-sync"}}{{.metadata.name}} {{end}}{{end}}{{end}}')
[ -z "$WRONG" ] && ok "somente pods do cloud-sync possuem role=metadata-accessor" \
  || fail "outros pods ainda têm role=metadata-accessor: $WRONG"

SYNC=$(pods_of $NS app=cloud-sync | head -1)
TRAINER=$(pods_of $NS app=trainer | head -1)
NOTEBOOK=$(pods_of $NS app=notebook | head -1)
[ -z "$SYNC" ] && fail "nenhum pod do cloud-sync em Running"
[ -z "$TRAINER" ] && fail "nenhum pod do trainer em Running"
[ -z "$NOTEBOOK" ] && fail "pod notebook não está em Running (não o remova)"

# ---------- comportamento ----------
if [ -n "$SYNC" ]; then
  can $NS "$SYNC" "$META" && ok "cloud-sync ($SYNC) acessa o metadata" \
    || fail "cloud-sync ($SYNC) deveria acessar 169.254.169.254"
fi
for p in $TRAINER $NOTEBOOK; do
  can $NS "$p" "$META" && fail "$p ainda acessa 169.254.169.254" || ok "$p NÃO acessa 169.254.169.254"
done

for p in $SYNC $TRAINER $NOTEBOOK; do
  dns $NS "$p"          && ok "$p resolve DNS"                    || fail "$p não resolve DNS (kubernetes.default.svc.cluster.local)"
  can $NS "$p" "$STORE" && ok "$p acessa model-store.storage"     || fail "$p não acessa http://model-store.storage.svc.cluster.local"
  can $NS "$p" "$EXT"   && ok "$p acessa o destino externo 198.51.100.10" || fail "$p não acessa 198.51.100.10"
done

finish
