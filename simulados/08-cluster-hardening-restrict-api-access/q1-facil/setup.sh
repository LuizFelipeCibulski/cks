#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml

# Aplica um manifest novo do kube-apiserver e espera o restart (se houve mudança)
apply_apiserver_manifest() {
  local new=$1 old cur
  if cmp -s "$new" "$MAN"; then rm -f "$new"; return 0; fi
  old=$(crictl ps -q --name '^kube-apiserver$' 2>/dev/null | head -1)
  cp "$new" "$MAN"; rm -f "$new"
  info "Manifest do kube-apiserver alterado; aguardando reinício..."
  for _ in $(seq 1 60); do
    cur=$(crictl ps -q --name '^kube-apiserver$' 2>/dev/null | head -1)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 2
  done
  wait_apiserver
}

# estado limpo: manifest original do kube-apiserver (backup em /root/cks-backup)
backup_manifest kube-apiserver.yaml
TMP=$(mktemp); cp /root/cks-backup/kube-apiserver.yaml "$TMP"
apply_apiserver_manifest "$TMP"
rm -f /etc/kubernetes/pki/auth-tokens.csv   # resto de outra questão (não referenciado pelo manifest original)

# Service kubernetes de volta a ClusterIP (caso outra questão tenha deixado NodePort)
if [ "$(kubectl get svc kubernetes -o jsonpath='{.spec.type}')" = "NodePort" ]; then
  kubectl patch svc kubernetes --type json -p '[{"op":"replace","path":"/spec/type","value":"ClusterIP"},{"op":"remove","path":"/spec/ports/0/nodePort"}]' >/dev/null 2>&1
fi

info "Criando cenário..."
kubectl delete clusterrolebinding metrics-public-access kubelet-debug-access --ignore-not-found >/dev/null
kubectl delete clusterrole node-debug-reader --ignore-not-found >/dev/null
rm -rf /opt/course/8/q1; mkdir -p /opt/course/8/q1

kubectl create clusterrole node-debug-reader --verb=get,list,watch --resource=nodes,pods,secrets >/dev/null
kubectl create clusterrolebinding metrics-public-access --clusterrole=view --group=system:unauthenticated >/dev/null
kubectl create clusterrolebinding kubelet-debug-access --clusterrole=node-debug-reader --user=system:anonymous >/dev/null

echo
echo "Ambiente pronto! Leia o enunciado.md"
