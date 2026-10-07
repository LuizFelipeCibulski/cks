#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace finance..."
ns_fresh finance
kubectl -n finance create serviceaccount report-bot >/dev/null
kubectl -n finance run ledger --image=nginx:1.27-alpine --labels=app=ledger >/dev/null
kubectl -n finance create secret generic bank-credentials --from-literal=token=s3cr3t >/dev/null
wait_pods finance

echo
echo "Ambiente pronto! Leia o enunciado.md"
