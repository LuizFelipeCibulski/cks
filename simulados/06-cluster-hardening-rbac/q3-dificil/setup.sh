#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

command -v openssl >/dev/null || { info "Instalando openssl..."; apt-get install -y openssl >/dev/null 2>&1; }

info "Limpando tentativas anteriores..."
kubectl delete csr dev-maria --ignore-not-found >/dev/null
# ClusterRoleBindings de tentativas anteriores envolvendo dev-maria / developers / ci-runner
for crb in $(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .subjects[*]}{.name}{","}{end}{"\n"}{end}' \
             | awk -F'|' '$2 ~ /(^|,)(dev-maria|developers|ci-runner),/ {print $1}'); do
  kubectl delete clusterrolebinding "$crb" >/dev/null
done
rm -rf /opt/course/6/q3; mkdir -p /opt/course/6/q3

ns_fresh project-x
kubectl -n project-x create serviceaccount ci-runner >/dev/null
kubectl -n project-x create rolebinding ci-runner-view --clusterrole=view --serviceaccount=project-x:ci-runner >/dev/null
kubectl -n project-x create deployment api --image=nginx:1.27-alpine >/dev/null
kubectl -n project-x create secret generic api-db --from-literal=password=Sup3rS3cret >/dev/null

# "configurações antigas" com permissões excessivas
kubectl create clusterrolebinding developers-admin --clusterrole=cluster-admin --group=developers >/dev/null
kubectl -n project-x create rolebinding project-x-legacy-editors --clusterrole=edit --user=dev-maria >/dev/null
kubectl create clusterrolebinding ci-pipeline-deployer --clusterrole=cluster-admin --serviceaccount=project-x:ci-runner >/dev/null

wait_pods project-x

echo
echo "Ambiente pronto! Leia o enunciado.md"
