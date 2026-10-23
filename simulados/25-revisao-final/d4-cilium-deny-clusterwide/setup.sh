#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane; require_cilium
has_internet || echo "AVISO: o controlplane não acessa a internet; os testes com 'world' vão falhar."
kubectl delete ccnp debug-deny-world --ignore-not-found >/dev/null 2>&1
ns_fresh d4; ns_fresh d4-other
CURL=curlimages/curl:8.10.1
kubectl -n d4 run db --image=nginx:1.27-alpine -l app=db --port 80 --expose >/dev/null
kubectl -n d4 run app --image=$CURL -l app=app --command -- sleep infinity >/dev/null
kubectl -n d4 run debug --image=$CURL -l app=debug,role=debug --command -- sleep infinity >/dev/null
kubectl -n d4-other run echo --image=nginx:1.27-alpine -l app=echo --port 80 --expose >/dev/null
kubectl -n d4-other run client --image=$CURL -l app=client --command -- sleep infinity >/dev/null
kubectl -n d4-other run scanner --image=$CURL -l app=scanner,role=debug --command -- sleep infinity >/dev/null
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: legacy-allow-all
  namespace: d4
spec:
  endpointSelector:
    matchLabels:
      app: db
  ingress:
  - fromEntities:
    - all
YAML
wait_pods d4; wait_pods d4-other
echo; ok "Ambiente pronto! Leia o enunciado.md"
