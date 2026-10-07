#!/usr/bin/env bash
# Network Policies — Q1 (Fácil): default deny ingress + egress
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# Pod web simples (busybox httpd) que responde o próprio nome
web_pod() { # ns nome labels
  kubectl -n "$1" run "$2" --image=busybox:1.36 --labels="$3" --port=80 \
    --command -- sh -c "mkdir -p /www && echo $2 > /www/index.html && httpd -f -p 80 -h /www" >/dev/null
}

info "Recriando namespaces restricted e cks-probe..."
ns_fresh restricted
ns_fresh cks-probe

info "Criando Pods..."
web_pod restricted app1 app=app1
web_pod restricted app2 app=app2
web_pod cks-probe probe app=probe
kubectl -n restricted expose pod app1 --port=80 >/dev/null
kubectl -n restricted expose pod app2 --port=80 >/dev/null
kubectl -n cks-probe expose pod probe --port=80 >/dev/null

rm -rf /opt/course/netpol/q1
mkdir -p /opt/course/netpol/q1

wait_pods restricted
wait_pods cks-probe

echo
echo "Ambiente pronto! Leia o enunciado.md"
