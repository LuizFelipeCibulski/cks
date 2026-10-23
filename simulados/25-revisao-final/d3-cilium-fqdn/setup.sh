#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane; require_cilium
has_internet || echo "AVISO: o controlplane não acessa a internet; os testes de FQDN vão falhar."
ns_fresh d3
kubectl -n d3 run cache --image=nginx:1.27-alpine -l app=cache --port 80 --expose >/dev/null
kubectl -n d3 run crawler --image=curlimages/curl:8.10.1 -l app=crawler --command -- sleep infinity >/dev/null
wait_pods d3
echo; ok "Ambiente pronto! Leia o enunciado.md"
