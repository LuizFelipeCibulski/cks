#!/usr/bin/env bash
# Network Policies — Q2 (Médio): namespaceSelector + podSelector (AND) e egress com DNS
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

web_pod() { # ns nome labels
  kubectl -n "$1" run "$2" --image=busybox:1.36 --labels="$3" --port=80 \
    --command -- sh -c "mkdir -p /www && echo $1/$2 > /www/index.html && httpd -f -p 80 -h /www" >/dev/null
}

info "Recriando namespaces orders, payments e sandbox..."
for ns in orders payments sandbox; do ns_fresh "$ns"; done

info "Criando Pods e Services..."
web_pod orders api app=api
web_pod orders worker app=worker
web_pod payments gateway app=gateway
web_pod payments ledger app=ledger
web_pod sandbox api app=api
kubectl -n orders expose pod api --port=80 >/dev/null
kubectl -n payments expose pod gateway --port=80 >/dev/null
kubectl -n payments expose pod ledger --port=80 >/dev/null

for ns in orders payments sandbox; do wait_pods "$ns"; done

echo
echo "Ambiente pronto! Leia o enunciado.md"
