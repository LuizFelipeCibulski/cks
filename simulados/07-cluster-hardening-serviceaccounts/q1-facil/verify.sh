#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=payments
AM=$(kubectl -n $NS get sa backend-sa -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
[ "$AM" = "false" ] && ok "SA backend-sa com automountServiceAccountToken: false" || fail "SA backend-sa ausente ou sem automountServiceAccountToken: false"

SAN=$(kubectl -n $NS get pod backend -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null)
[ "$SAN" = "backend-sa" ] && ok "Pod backend usa a SA backend-sa" || fail "Pod backend ausente ou não usa backend-sa ($SAN)"

IMG=$(kubectl -n $NS get pod backend -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)
[ "$IMG" = "nginx:1.27-alpine" ] && ok "Imagem correta" || fail "Imagem incorreta ($IMG)"

kubectl -n $NS wait --for=condition=Ready pod/backend --timeout=60s >/dev/null 2>&1 && ok "Pod backend Running/Ready" || fail "Pod backend não está Ready"

VOLS=$(kubectl -n $NS get pod backend -o jsonpath='{.spec.volumes[*].projected.sources[*].serviceAccountToken.path}' 2>/dev/null)
[ -z "$VOLS" ] && ok "Nenhum volume de token projetado no Pod" || fail "Pod ainda tem volume de token de ServiceAccount"

if kubectl -n $NS exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount/token >/dev/null 2>&1; then
  fail "Token encontrado dentro do container"
else
  ok "Token não está montado no container"
fi

finish
