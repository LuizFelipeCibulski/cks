#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
source "$(dirname "$(readlink -f "$0")")/../lib/gvisor.sh"
require_root
require_controlplane

T=$(target_node)
CP=$(kubectl get nodes --no-headers -l node-role.kubernetes.io/control-plane -o custom-columns=N:.metadata.name | head -1)
info "Nó alvo: $T"

info "Restaurando o config.toml original do containerd em todos os nós (sem handler runsc)..."
for n in $(all_nodes); do on_node "$n" restore; done
info "Instalando SOMENTE os binários do gVisor no nó $T..."
on_node "$T" install || { echo "Falha ao instalar o gVisor em $T"; exit 1; }
on_node "$T" status

kubectl delete runtimeclass gvisor-sandbox --ignore-not-found >/dev/null
for n in $(all_nodes); do kubectl label node "$n" sandbox.cks.io/runtime- >/dev/null 2>&1; done
kubectl wait --for=condition=Ready node --all --timeout=120s >/dev/null 2>&1

info "Recriando namespace payments..."
ns_fresh payments
rm -rf /opt/course/16/q3 && mkdir -p /opt/course/16/q3
echo "$T" > /opt/course/16/q3/target-node.txt

kubectl -n payments create deployment gateway --image=nginx:1.27-alpine --replicas=2 >/dev/null
kubectl -n payments create deployment processor --image=busybox:1.36 --replicas=1 -- sh -c 'sleep 1d' >/dev/null
if [ -n "$CP" ] && [ "$CP" != "$T" ]; then
  # "fixado" no controlplane por um colega, ignorando o scheduler
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reports
  namespace: payments
  labels: {app: reports}
spec:
  replicas: 1
  selector:
    matchLabels: {app: reports}
  template:
    metadata:
      labels: {app: reports}
    spec:
      nodeName: $CP
      containers:
      - name: reports
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
YAML
else
  kubectl -n payments create deployment reports --image=busybox:1.36 --replicas=1 -- sh -c 'sleep 1d' >/dev/null
fi
kubectl -n payments rollout status deploy --timeout=180s >/dev/null 2>&1

echo
echo "Nó alvo deste exercício: $T"
echo "Ambiente pronto! Leia o enunciado.md"
