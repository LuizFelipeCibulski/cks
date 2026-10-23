#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane
apiserver_reset
rm -rf /etc/kubernetes/enc /opt/course/25/d7; mkdir -p /opt/course/25/d7
ns_fresh d7
kubectl -n d7 create secret generic db-creds --from-literal=username=admin --from-literal=password='S3cr3t!' >/dev/null
kubectl -n d7 create secret generic api-token --from-literal=token=abc123 >/dev/null
echo; ok "Ambiente pronto! Leia o enunciado.md"
