#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=seccomp-q1

check_pod() {  # check_pod <pod> <image esperada do 1º container>
  local p=$1 img=$2 podt c ct eff mode
  if ! kubectl -n "$NS" get pod "$p" >/dev/null 2>&1; then fail "Pod $p não existe"; return; fi
  kubectl -n "$NS" wait --for=condition=Ready pod/"$p" --timeout=60s >/dev/null 2>&1 \
    && ok "Pod $p Running" || fail "Pod $p não está Running/Ready"
  [ "$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.containers[0].image}')" = "$img" ] \
    && ok "Pod $p mantém a imagem $img" || fail "Pod $p com imagem diferente de $img"
  podt=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.securityContext.seccompProfile.type}')
  for c in $(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.containers[*].name}'); do
    ct=$(kubectl -n "$NS" get pod "$p" -o jsonpath="{.spec.containers[?(@.name=='$c')].securityContext.seccompProfile.type}")
    eff=${ct:-$podt}
    [ "$eff" = "RuntimeDefault" ] && ok "$p/$c: seccompProfile efetivo RuntimeDefault" \
      || fail "$p/$c: seccompProfile efetivo '${eff:-nenhum}' (esperado RuntimeDefault)"
    mode=$(kubectl -n "$NS" exec "$p" -c "$c" -- cat /proc/1/status 2>/dev/null | awk '/^Seccomp:/{print $2}')
    [ "$mode" = "2" ] && ok "$p/$c: filtro seccomp ativo no processo (Seccomp: 2)" \
      || fail "$p/$c: processo com Seccomp: '${mode:-?}' (esperado 2)"
  done
}

check_pod web nginx:1.27-alpine
check_pod legacy busybox:1.36

finish
