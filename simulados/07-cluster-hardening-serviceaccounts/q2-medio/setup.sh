#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace orders..."
ns_fresh orders
kubectl -n orders create serviceaccount orders-ci >/dev/null
kubectl -n orders create deployment orders-web --image=nginx:1.27-alpine --replicas=2 >/dev/null
rm -rf /opt/course/7/q2; mkdir -p /opt/course/7/q2
kubectl -n orders rollout status deploy/orders-web --timeout=120s >/dev/null 2>&1

echo
echo "Ambiente pronto! Leia o enunciado.md"
