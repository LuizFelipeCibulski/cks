#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane

falco_reset
rm -rf /var/log/falco
sha256sum /etc/falco/falco_rules.yaml > /root/cks-backup/d1-falco_rules.sha256

ns_fresh d1
kubectl -n d1 run webshell --image=nginx:1.27-alpine >/dev/null
wait_pods d1
echo; ok "Ambiente pronto! Leia o enunciado.md"
