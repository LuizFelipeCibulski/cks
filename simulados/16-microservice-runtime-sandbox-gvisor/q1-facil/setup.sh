#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
source "$(dirname "$(readlink -f "$0")")/../lib/gvisor.sh"
require_root
require_controlplane

info "Instalando gVisor e registrando o handler runsc no containerd de todos os nós..."
for n in $(all_nodes); do
  on_node "$n" install && on_node "$n" enable
  on_node "$n" status
done

kubectl delete runtimeclass gvisor --ignore-not-found >/dev/null
info "Recriando namespace sandbox..."
ns_fresh sandbox
echo
echo "Ambiente pronto! Leia o enunciado.md"
