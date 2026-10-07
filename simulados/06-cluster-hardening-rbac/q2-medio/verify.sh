#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

can() { [ "$(kubectl auth can-i "$@" 2>/dev/null)" = "yes" ]; }
CI=system:serviceaccount:team-b:ci
LEG=system:serviceaccount:team-b:legacy

kubectl get clusterrole app-viewer >/dev/null 2>&1 && ok "ClusterRole app-viewer existe" || fail "ClusterRole app-viewer não existe"

REF=$(kubectl -n team-a get rolebinding jane-app-viewer -o jsonpath='{.roleRef.kind}/{.roleRef.name}' 2>/dev/null)
[ "$REF" = "ClusterRole/app-viewer" ] && ok "RoleBinding team-a/jane-app-viewer -> ClusterRole/app-viewer" \
  || fail "RoleBinding team-a/jane-app-viewer ausente ou roleRef incorreto ($REF)"
REF=$(kubectl -n team-b get rolebinding ci-app-viewer -o jsonpath='{.roleRef.kind}/{.roleRef.name}' 2>/dev/null)
[ "$REF" = "ClusterRole/app-viewer" ] && ok "RoleBinding team-b/ci-app-viewer -> ClusterRole/app-viewer" \
  || fail "RoleBinding team-b/ci-app-viewer ausente ou roleRef incorreto ($REF)"

# jane
for v in get list watch; do
  can "$v" deployments.apps -n team-a --as jane && ok "jane pode $v deployments em team-a" || fail "jane NÃO pode $v deployments em team-a"
done
can list configmaps -n team-a --as jane && ok "jane pode listar configmaps em team-a" || fail "jane NÃO pode listar configmaps em team-a"
can list deployments.apps -n team-b --as jane && fail "jane consegue listar deployments em team-b" || ok "jane não tem acesso a team-b"
can delete deployments.apps -n team-a --as jane && fail "jane pode deletar deployments (excesso)" || ok "jane não pode deletar deployments"
can get secrets -n team-a --as jane && fail "jane pode ler secrets (excesso)" || ok "jane não pode ler secrets"
can list pods -n team-a --as jane && fail "jane pode listar pods (fora do pedido)" || ok "jane não lista pods"
can list deployments.apps -A --as jane && fail "jane tem acesso cluster-wide" || ok "jane não tem acesso cluster-wide"

# ci
can list deployments.apps -n team-b --as "$CI" && ok "SA ci lista deployments em team-b" || fail "SA ci NÃO lista deployments em team-b"
can get configmaps -n team-b --as "$CI" && ok "SA ci lê configmaps em team-b" || fail "SA ci NÃO lê configmaps em team-b"
can list deployments.apps -n team-a --as "$CI" && fail "SA ci consegue listar deployments em team-a" || ok "SA ci não tem acesso a team-a"
can create deployments.apps -n team-b --as "$CI" && fail "SA ci pode criar deployments (excesso)" || ok "SA ci não cria deployments"

# legacy
F=/opt/course/6/q2/legacy.txt
if [ -f "$F" ]; then
  ans() { can "$@" && echo yes || echo no; }
  chk() { # chave esperado
    got=$(grep -iE "^[[:space:]]*$1[[:space:]]*:" "$F" | head -1 | cut -d: -f2 | tr -d ' \r\t' | tr '[:upper:]' '[:lower:]')
    [ "$got" = "$2" ] && ok "legacy.txt: $1 = $2" || fail "legacy.txt: $1 incorreto ou ausente"
  }
  chk list-pods-team-a "$(ans list pods -n team-a --as "$LEG")"
  chk get-secrets-team-a "$(ans get secrets -n team-a --as "$LEG")"
  chk delete-deployments-team-a "$(ans delete deployments.apps -n team-a --as "$LEG")"
else
  fail "$F não existe"
fi

finish
