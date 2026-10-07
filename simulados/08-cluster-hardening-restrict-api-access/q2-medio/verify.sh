#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
PORT=$(grep -oE -- '--secure-port=[0-9]+' "$MAN" | cut -d= -f2); PORT=${PORT:-6443}

# apiserver de pé (tolera reinício recente)
UP=0
for _ in $(seq 1 30); do kubectl get --raw=/readyz >/dev/null 2>&1 && { UP=1; break; }; sleep 2; done
[ "$UP" = 1 ] && ok "kube-apiserver respondendo" || { fail "kube-apiserver não responde"; finish; }

# 1. NodePort
grep -qE -- '--kubernetes-service-node-port=[1-9]' "$MAN" && fail "Flag --kubernetes-service-node-port ainda configurada" || ok "Flag --kubernetes-service-node-port removida"
T=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.type}')
[ "$T" = "ClusterIP" ] && ok "Service kubernetes é ClusterIP" || fail "Service kubernetes é $T"
NP=$(kubectl get svc kubernetes -n default -o jsonpath='{.spec.ports[*].nodePort}')
[ -z "$NP" ] && ok "Service kubernetes sem nodePort" || fail "Service kubernetes ainda tem nodePort $NP"
NODEIP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
C=$(curl -sk -m 4 -o /dev/null -w '%{http_code}' "https://$NODEIP:31000/version")
[ "$C" = "000" ] && ok "Porta 31000 não responde" || fail "https://$NODEIP:31000 ainda responde (HTTP $C)"

# 2. anonymous
C=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/api")
[ "$C" = "401" ] && ok "Requisição anônima a /api recebe 401" || fail "Requisição anônima a /api retornou HTTP $C (esperado 401)"

# 3. NodeRestriction
grep -E -- '--enable-admission-plugins=' "$MAN" | grep -q NodeRestriction && ok "NodeRestriction em --enable-admission-plugins" || fail "NodeRestriction não está em --enable-admission-plugins"
KCERT=/var/lib/kubelet/pki/kubelet-client-current.pem
NODE=$(openssl x509 -in "$KCERT" -noout -subject 2>/dev/null | sed -E 's/.*system:node:([^ ,/]+).*/\1/')
NODE=${NODE:-$(hostname)}
if kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node "$NODE" node-restriction.kubernetes.io/cks-test=1 --overwrite >/dev/null 2>&1; then
  fail "Kubelet conseguiu adicionar label node-restriction.kubernetes.io/* (NodeRestriction inativo)"
  kubectl label node "$NODE" node-restriction.kubernetes.io/cks-test- >/dev/null 2>&1
else
  ok "Kubelet impedido de alterar labels protegidos (NodeRestriction ativo)"
fi

# 4. admin
kubectl get nodes >/dev/null 2>&1 && ok "kubectl admin funcionando" || fail "kubectl admin não funciona"

finish
