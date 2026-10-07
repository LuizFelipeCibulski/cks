#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=orders

kubectl -n $NS get sa orders-web-sa >/dev/null 2>&1 && ok "SA orders-web-sa existe" || fail "SA orders-web-sa não existe"
SAN=$(kubectl -n $NS get deploy orders-web -o jsonpath='{.spec.template.spec.serviceAccountName}' 2>/dev/null)
[ "$SAN" = "orders-web-sa" ] && ok "Deployment orders-web usa orders-web-sa" || fail "Deployment orders-web não usa orders-web-sa ($SAN)"

AM=$(kubectl -n $NS get sa default -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$AM" = "false" ] && ok "SA default com automountServiceAccountToken: false" || fail "SA default ainda monta token automaticamente"

if kubectl -n $NS rollout status deploy/orders-web --timeout=90s >/dev/null 2>&1; then
  ok "Deployment orders-web disponível"
else
  fail "Deployment orders-web não concluiu o rollout"
fi
sleep 3

# pods atuais (ignora os que estão terminando)
PODS=$(kubectl -n $NS get pods -l app=orders-web --no-headers \
  -o custom-columns='N:.metadata.name,D:.metadata.deletionTimestamp,S:.spec.serviceAccountName' 2>/dev/null | awk '$2=="<none>"{print $1" "$3}')
[ -z "$PODS" ] && fail "Nenhum Pod do orders-web encontrado"
while read -r p sa; do
  [ -z "$p" ] && continue
  [ "$sa" = "orders-web-sa" ] || fail "Pod $p não usa orders-web-sa"
  T=$(kubectl -n $NS get pod "$p" -o jsonpath='{.spec.volumes[*].projected.sources[*].serviceAccountToken.path}')
  if [ -z "$T" ] && ! kubectl -n $NS exec "$p" -- ls /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null 2>&1; then
    ok "Pod $p sem token montado"
  else
    fail "Pod $p ainda tem token de ServiceAccount montado"
  fi
done <<< "$PODS"

# token do orders-ci
F=/opt/course/7/q2/orders-ci.token
TOKEN=$(tr -d ' \r\n\t' < "$F" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  fail "$F não existe ou está vazio"
else
  RES=$(cat <<EOF | kubectl create -o jsonpath='{.status.authenticated} {.status.user.username}' -f - 2>/dev/null
apiVersion: authentication.k8s.io/v1
kind: TokenReview
spec:
  token: "$TOKEN"
EOF
)
  [ "$RES" = "true system:serviceaccount:orders:orders-ci" ] && ok "Token válido para system:serviceaccount:orders:orders-ci" \
    || fail "Token inválido ou de outra identidade ($RES)"
  P=$(echo "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
  case $(( ${#P} % 4 )) in 2) P="$P==";; 3) P="$P=";; esac
  PAYLOAD=$(echo "$P" | base64 -d 2>/dev/null)
  EXP=$(echo "$PAYLOAD" | grep -o '"exp":[0-9]*' | cut -d: -f2)
  IAT=$(echo "$PAYLOAD" | grep -o '"iat":[0-9]*' | cut -d: -f2)
  if [ -n "$EXP" ] && [ -n "$IAT" ] && [ $((EXP - IAT)) -ge 3500 ] && [ $((EXP - IAT)) -le 3700 ]; then
    ok "Token com validade de 1h"
  else
    fail "Validade do token não é 1h (exp-iat=$((${EXP:-0} - ${IAT:-0}))s)"
  fi
fi

N=$(kubectl -n $NS get secrets --field-selector type=kubernetes.io/service-account-token --no-headers 2>/dev/null | wc -l)
[ "$N" -eq 0 ] && ok "Nenhum Secret de token de longa duração criado" || fail "Existe Secret do tipo service-account-token em $NS"

finish
