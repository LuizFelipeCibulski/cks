#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=observer
SA=system:serviceaccount:observer:pod-lister-sa
DEF=system:serviceaccount:observer:default
can() { [ "$(kubectl auth can-i "$@" 2>/dev/null)" = "yes" ]; }

# audiences aceitas pelo apiserver
MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
AUDS=$(grep -- '--api-audiences=' "$MAN" | head -1 | sed 's/.*--api-audiences=//' | tr -d '"')
[ -z "$AUDS" ] && AUDS=$(grep -- '--service-account-issuer=' "$MAN" | head -1 | sed 's/.*--service-account-issuer=//' | tr -d '"')

# 1. SA
AM=$(kubectl -n $NS get sa pod-lister-sa -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$AM" = "false" ] && ok "SA pod-lister-sa com automount desabilitado" || fail "SA pod-lister-sa ausente ou com automount habilitado"

# 2. RBAC
kubectl -n $NS get role pod-list >/dev/null 2>&1 && ok "Role pod-list existe" || fail "Role pod-list não existe"
REF=$(kubectl -n $NS get rolebinding pod-lister-sa-pod-list -o jsonpath='{.roleRef.kind}/{.roleRef.name}' 2>/dev/null)
[ "$REF" = "Role/pod-list" ] && ok "RoleBinding pod-lister-sa-pod-list -> Role/pod-list" || fail "RoleBinding pod-lister-sa-pod-list ausente/incorreta ($REF)"
can list pods -n $NS --as $SA && ok "pod-lister-sa lista pods" || fail "pod-lister-sa NÃO lista pods"
can get pods -n $NS --as $SA && ok "pod-lister-sa lê pods" || fail "pod-lister-sa NÃO lê pods"
can delete pods -n $NS --as $SA && fail "pod-lister-sa pode deletar pods (excesso)" || ok "pod-lister-sa não deleta pods"
can list secrets -n $NS --as $SA && fail "pod-lister-sa pode listar secrets (excesso)" || ok "pod-lister-sa não lista secrets"
can list pods -n default --as $SA && fail "pod-lister-sa lista pods em outros namespaces" || ok "pod-lister-sa restrita a observer"

# 3. Pod pod-lister
J() { kubectl -n $NS get pod pod-lister -o jsonpath="$1" 2>/dev/null; }
[ "$(J '{.spec.serviceAccountName}')" = "pod-lister-sa" ] && ok "pod-lister usa pod-lister-sa" || fail "pod-lister não usa pod-lister-sa"
[ "$(J '{.spec.containers[0].image}')" = "curlimages/curl:8.10.1" ] && ok "Imagem mantida" || fail "Imagem do pod-lister alterada"
J '{.spec.volumes[*].name}' | grep -q 'kube-api-access' && fail "pod-lister ainda tem o volume kube-api-access" || ok "pod-lister sem kube-api-access"
EXPS=$(J '{.spec.volumes[*].projected.sources[*].serviceAccountToken.expirationSeconds}')
[ "$EXPS" = "3600" ] && ok "Token projetado com expirationSeconds 3600" || fail "expirationSeconds do token projetado incorreto ($EXPS)"
AUD=$(J '{.spec.volumes[*].projected.sources[*].serviceAccountToken.audience}')
if [ -z "$AUD" ] || echo ",$AUDS," | grep -q ",$AUD,"; then
  ok "Audience do token aceita pelo apiserver (${AUD:-padrão})"
else
  fail "Audience '$AUD' não é aceita pelo apiserver (aceitas: $AUDS)"
fi
kubectl -n $NS wait --for=condition=Ready pod/pod-lister --timeout=60s >/dev/null 2>&1 && ok "pod-lister Ready" || fail "pod-lister não está Ready"

TD=/var/run/secrets/tokens
kubectl -n $NS exec pod-lister -- test -s $TD/token 2>/dev/null && ok "Token em $TD/token" || fail "Token não encontrado em $TD/token"
kubectl -n $NS exec pod-lister -- test -s $TD/ca.crt 2>/dev/null && ok "CA em $TD/ca.crt" || fail "CA não encontrada em $TD/ca.crt"

code() {
  kubectl -n $NS exec pod-lister -- sh -c "curl -s -m 5 -o /dev/null -w '%{http_code}' --cacert $TD/ca.crt \
    -H \"Authorization: Bearer \$(cat $TD/token)\" https://kubernetes.default.svc$1" 2>/dev/null
}
C=$(code /api/v1/namespaces/observer/pods)
[ "$C" = "200" ] && ok "curl lista pods de observer (HTTP 200)" || fail "curl para listar pods retornou HTTP '$C' (esperado 200)"
C=$(code /api/v1/namespaces/observer/secrets)
[ "$C" = "403" ] && ok "curl para secrets negado (HTTP 403)" || fail "curl para secrets retornou HTTP '$C' (esperado 403)"

# 4. outros pods e SA default
for d in web cache; do
  kubectl -n $NS rollout status deploy/$d --timeout=90s >/dev/null 2>&1 && ok "Deployment $d disponível" || fail "Deployment $d indisponível"
done
sleep 2
OTHERS=$(kubectl -n $NS get pods --no-headers -o custom-columns='N:.metadata.name,D:.metadata.deletionTimestamp' 2>/dev/null \
  | awk '$2=="<none>" && $1!="pod-lister"{print $1}')
for p in $OTHERS; do
  T=$(kubectl -n $NS get pod "$p" -o jsonpath='{.spec.volumes[*].projected.sources[*].serviceAccountToken.path}')
  [ -z "$T" ] && ok "Pod $p sem token de ServiceAccount" || fail "Pod $p ainda tem token de ServiceAccount montado"
done
can list pods -n $NS --as $DEF && fail "SA default ainda tem permissões em observer" || ok "SA default sem permissões RBAC"
can get configmaps -n $NS --as $DEF && fail "SA default ainda lê configmaps" || true

finish
