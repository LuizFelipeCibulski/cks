#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace payments..."
ns_fresh payments
kubectl -n payments create deployment frontend --image=nginx:1.27-alpine >/dev/null
wait_pods payments

echo
echo "Ambiente pronto! Leia o enunciado.md"
