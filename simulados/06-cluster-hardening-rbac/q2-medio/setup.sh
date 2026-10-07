#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespaces team-a e team-b..."
ns_fresh team-a
ns_fresh team-b
kubectl delete clusterrole app-viewer --ignore-not-found >/dev/null
# remove ClusterRoleBindings de tentativas anteriores que concedam algo a jane
for crb in $(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .subjects[*]}{.name}{","}{end}{"\n"}{end}' \
             | awk -F'|' '$2 ~ /(^|,)jane,/ {print $1}'); do
  kubectl delete clusterrolebinding "$crb" >/dev/null
done

kubectl -n team-b create serviceaccount ci >/dev/null
kubectl -n team-b create serviceaccount legacy >/dev/null

for ns in team-a team-b; do
  kubectl -n "$ns" create deployment web --image=nginx:1.27-alpine --replicas=1 >/dev/null
  kubectl -n "$ns" create configmap web-config --from-literal=mode=prod >/dev/null
  kubectl -n "$ns" create secret generic db-pass --from-literal=password=changeme >/dev/null
done

# permissão herdada da SA legacy (team-b) dentro de team-a
kubectl -n team-a create rolebinding legacy-access --clusterrole=view --serviceaccount=team-b:legacy >/dev/null

rm -rf /opt/course/6/q2; mkdir -p /opt/course/6/q2

echo
echo "Ambiente pronto! Leia o enunciado.md"
