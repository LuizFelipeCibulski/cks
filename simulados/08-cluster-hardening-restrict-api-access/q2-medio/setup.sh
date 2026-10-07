#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml

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

backup_manifest kube-apiserver.yaml
rm -f /etc/kubernetes/pki/auth-tokens.csv   # resto de outra questão
TMP=$(mktemp); cp /root/cks-backup/kube-apiserver.yaml "$TMP"

info "Aplicando configuração insegura no kube-apiserver..."
# remove NodeRestriction da lista de admission plugins
sed -i -E 's/(--enable-admission-plugins=)NodeRestriction,?/\1/; s/(--enable-admission-plugins=.*),NodeRestriction/\1/' "$TMP"
sed -i -E '/--enable-admission-plugins=[[:space:]]*$/d' "$TMP"
# anonymous explícito + exposição via NodePort
sed -i -E '/--anonymous-auth=/d; /--kubernetes-service-node-port=/d' "$TMP"
sed -i -E 's/^([[:space:]]*)- kube-apiserver[[:space:]]*$/&\n\1- --anonymous-auth=true\n\1- --kubernetes-service-node-port=31000/' "$TMP"
apply_apiserver_manifest "$TMP"

# garante que o Service kubernetes esteja como NodePort (o apiserver reconcilia, mas por garantia)
sleep 5
if [ "$(kubectl get svc kubernetes -o jsonpath='{.spec.type}')" != "NodePort" ]; then
  TP=$(kubectl get svc kubernetes -o jsonpath='{.spec.ports[0].targetPort}')
  kubectl patch svc kubernetes --type merge -p "{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"name\":\"https\",\"port\":443,\"protocol\":\"TCP\",\"targetPort\":${TP:-6443},\"nodePort\":31000}]}}" >/dev/null
fi

kubectl label node --all node-restriction.kubernetes.io/cks-test- >/dev/null 2>&1

echo
echo "Ambiente pronto! Leia o enunciado.md"
