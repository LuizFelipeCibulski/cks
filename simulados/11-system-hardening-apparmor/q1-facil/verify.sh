#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=apparmor-q1
P=k8s-deny-write

grep -qx "$P (enforce)" /sys/kernel/security/apparmor/profiles \
  && ok "perfil $P carregado em enforce no controlplane" \
  || fail "perfil $P não está carregado em modo enforce (veja aa-status)"

if ! kubectl -n "$NS" get pod writer >/dev/null 2>&1; then
  fail "Pod writer não existe no namespace $NS"; finish
fi

SPEC=$(kubectl -n "$NS" get pod writer -o jsonpath='{.spec.securityContext.appArmorProfile.type}/{.spec.securityContext.appArmorProfile.localhostProfile} {.spec.containers[0].securityContext.appArmorProfile.type}/{.spec.containers[0].securityContext.appArmorProfile.localhostProfile}')
echo "$SPEC" | grep -q "Localhost/$P" \
  && ok "appArmorProfile Localhost/$P definido no securityContext" \
  || fail "o Pod não define securityContext.appArmorProfile type Localhost / localhostProfile $P"

kubectl -n "$NS" wait --for=condition=Ready pod/writer --timeout=60s >/dev/null 2>&1 \
  && ok "Pod writer Running" || fail "Pod writer não está Running/Ready"

CUR=$(kubectl -n "$NS" exec writer -- cat /proc/self/attr/current 2>/dev/null)
[ "$CUR" = "$P (enforce)" ] && ok "container confinado por '$CUR'" || fail "container confinado por '${CUR:-?}' (esperado '$P (enforce)')"

if [ -n "$CUR" ]; then
  kubectl -n "$NS" exec writer -- touch /tmp/cks-test >/dev/null 2>&1 \
    && fail "escrita em /tmp foi permitida (deveria ser negada)" \
    || ok "escrita negada pelo perfil"
fi

finish
