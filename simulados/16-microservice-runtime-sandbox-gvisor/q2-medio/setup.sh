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

kubectl delete runtimeclass gvisor secure-runtime kata --ignore-not-found >/dev/null
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: gvisor
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: secure-runtime
handler: runsc
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata-qemu
YAML

info "Recriando namespaces untrusted e trusted..."
ns_fresh untrusted
ns_fresh trusted
rm -rf /opt/course/16/q2 && mkdir -p /opt/course/16/q2

kubectl -n untrusted create deployment scanner --image=busybox:1.36 --replicas=2 -- sh -c 'sleep 1d' >/dev/null
kubectl -n untrusted create deployment uploader --image=nginx:1.27-alpine --replicas=1 >/dev/null
kubectl -n untrusted create deployment thumbnailer --image=busybox:1.36 --replicas=1 -- sh -c 'sleep 1d' >/dev/null
kubectl -n trusted create deployment portal --image=nginx:1.27-alpine --replicas=1 >/dev/null

for ns in untrusted trusted; do kubectl -n $ns rollout status deploy --timeout=180s >/dev/null 2>&1; done
echo
echo "Ambiente pronto! Leia o enunciado.md"
