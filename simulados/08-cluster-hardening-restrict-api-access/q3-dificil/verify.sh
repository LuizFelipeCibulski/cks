#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
PORT=$(grep -oE -- '--secure-port=[0-9]+' "$MAN" | cut -d= -f2); PORT=${PORT:-6443}
TOKEN=9f2c7d41e8b34a6f0c5d2e1b7a9f3c86

UP=0
for _ in $(seq 1 30); do kubectl get --raw=/readyz >/dev/null 2>&1 && { UP=1; break; }; sleep 2; done
[ "$UP" = 1 ] && ok "kube-apiserver respondendo" || { fail "kube-apiserver não responde"; finish; }

# 1. anonymous
C=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/api")
[ "$C" = "401" ] && ok "Requisição anônima a /api recebe 401" || fail "Requisição anônima a /api retornou HTTP $C (esperado 401)"
C=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/api/v1/secrets")
[ "$C" = "401" ] && ok "Requisição anônima a secrets recebe 401" || fail "Requisição anônima a secrets retornou HTTP $C"

# 2. authorization mode
AM=$(grep -oE -- '--authorization-mode=[^ "]*' "$MAN" | cut -d= -f2)
AC=$(grep -oE -- '--authorization-config=[^ "]*' "$MAN" | cut -d= -f2)
if [ -n "$AM" ]; then
  [ "$AM" = "Node,RBAC" ] && ok "--authorization-mode=Node,RBAC" || fail "--authorization-mode=$AM (esperado Node,RBAC)"
elif [ -n "$AC" ] && [ -f "$AC" ]; then
  TYPES=$(grep -E '^[[:space:]-]*type:' "$AC" | awk '{print $NF}' | tr -d '"' | paste -sd, -)
  [ "$TYPES" = "Node,RBAC" ] && ok "AuthorizationConfiguration com Node,RBAC" || fail "AuthorizationConfiguration com tipos: $TYPES"
else
  fail "Modo de autorização não configurado"
fi
[ "$(kubectl auth can-i list secrets -A --as cks-qualquer-usuario 2>/dev/null)" = "yes" ] \
  && fail "Usuário arbitrário ainda pode listar secrets (AlwaysAllow?)" || ok "Usuário arbitrário não tem acesso (sem AlwaysAllow)"

KCERT=/var/lib/kubelet/pki/kubelet-client-current.pem
NODE=$(openssl x509 -in "$KCERT" -noout -subject 2>/dev/null | sed -E 's/.*system:node:([^ ,/]+).*/\1/')
NODE=${NODE:-$(hostname)}
[ "$(kubectl auth can-i get "node/$NODE" --as "system:node:$NODE" --as-group system:nodes --as-group system:authenticated 2>/dev/null)" = "yes" ] \
  && ok "Node authorizer ativo (kubelet lê o próprio node)" || fail "Kubelet não consegue ler o próprio node (modo Node ausente?)"

# 3. NodeRestriction
grep -E -- '--enable-admission-plugins=' "$MAN" | grep -q NodeRestriction && ok "NodeRestriction em --enable-admission-plugins" || fail "NodeRestriction não habilitado"
if kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node "$NODE" node-restriction.kubernetes.io/cks-test=1 --overwrite >/dev/null 2>&1; then
  fail "Kubelet conseguiu adicionar label node-restriction.kubernetes.io/* (NodeRestriction inativo)"
  kubectl label node "$NODE" node-restriction.kubernetes.io/cks-test- >/dev/null 2>&1
else
  ok "Kubelet impedido de alterar labels protegidos"
fi

# 4. CRBs para anônimos
ANON=$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .subjects[*]}{.name}{","}{end}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$1!="system:public-info-viewer" && $2 ~ /(^|,)system:(anonymous|unauthenticated),/ {print $1}')
[ -z "$ANON" ] && ok "Nenhum ClusterRoleBinding extra para anônimos" || fail "ClusterRoleBindings para anônimos: $(echo $ANON)"
kubectl get clusterrolebinding system:public-info-viewer >/dev/null 2>&1 && ok "system:public-info-viewer preservado" || fail "system:public-info-viewer foi removido"

# 5. backdoor
B=$(tr -d ' \r\n\t' < /opt/course/8/q3/backdoor.txt 2>/dev/null)
[ "$B" = "ops-breakglass" ] && ok "backdoor.txt identifica o usuário" || fail "backdoor.txt ausente ou incorreto ('$B')"
C=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "https://127.0.0.1:$PORT/api/v1/namespaces/kube-system/secrets")
[ "$C" = "401" ] && ok "Token estático não autentica mais (401)" || fail "Token estático ainda aceito (HTTP $C)"
grep -q -- '--token-auth-file' "$MAN" && fail "--token-auth-file ainda presente no manifest" || ok "--token-auth-file removido"

# 6. saúde geral
kubectl get nodes >/dev/null 2>&1 && ok "kubectl admin funcionando" || fail "kubectl admin não funciona"
NR=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2!="Ready"' | wc -l)
[ "$NR" -eq 0 ] && ok "Todos os nodes Ready" || fail "$NR node(s) não Ready"
for c in kube-controller-manager kube-scheduler; do
  kubectl -n kube-system get pods -l component=$c -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True \
    && ok "$c Ready" || fail "$c não está Ready"
done

finish
