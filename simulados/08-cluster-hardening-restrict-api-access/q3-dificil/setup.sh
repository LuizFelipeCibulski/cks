#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
TOKFILE=/etc/kubernetes/pki/auth-tokens.csv

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
mkdir -p /opt/course/8/q3; rm -f /opt/course/8/q3/backdoor.txt

# credencial estática "de emergência" (dentro de /etc/kubernetes/pki, que já é montado no pod)
cat > "$TOKFILE" <<'EOF'
9f2c7d41e8b34a6f0c5d2e1b7a9f3c86,ops-breakglass,1337,"system:masters"
EOF
chmod 600 "$TOKFILE"

TMP=$(mktemp); cp /root/cks-backup/kube-apiserver.yaml "$TMP"
info "Aplicando configuração insegura no kube-apiserver..."
sed -i -E 's/(--authorization-mode=).*/\1AlwaysAllow/' "$TMP"
sed -i -E 's/(--enable-admission-plugins=)NodeRestriction,?/\1/; s/(--enable-admission-plugins=.*),NodeRestriction/\1/' "$TMP"
sed -i -E '/--enable-admission-plugins=[[:space:]]*$/d' "$TMP"
sed -i -E '/--anonymous-auth=/d; /--token-auth-file=/d' "$TMP"
sed -i -E "s#^([[:space:]]*)- kube-apiserver[[:space:]]*\$#&\n\1- --anonymous-auth=true\n\1- --token-auth-file=$TOKFILE#" "$TMP"
apply_apiserver_manifest "$TMP"

# Service kubernetes de volta a ClusterIP (caso outra questão tenha deixado NodePort)
if [ "$(kubectl get svc kubernetes -o jsonpath='{.spec.type}')" = "NodePort" ]; then
  kubectl patch svc kubernetes --type json -p '[{"op":"replace","path":"/spec/type","value":"ClusterIP"},{"op":"remove","path":"/spec/ports/0/nodePort"}]' >/dev/null 2>&1
fi

info "Criando permissões para anônimos..."
kubectl delete clusterrolebinding system:public-metrics-viewer --ignore-not-found >/dev/null
kubectl delete clusterrole system:public-metrics --ignore-not-found >/dev/null
kubectl create clusterrole system:public-metrics --verb=get,list,watch --resource=pods,secrets,nodes,configmaps >/dev/null
kubectl create clusterrolebinding system:public-metrics-viewer --clusterrole=system:public-metrics \
  --user=system:anonymous --group=system:unauthenticated >/dev/null
kubectl label node --all node-restriction.kubernetes.io/cks-test- >/dev/null 2>&1

echo
echo "Ambiente pronto! Leia o enunciado.md"
