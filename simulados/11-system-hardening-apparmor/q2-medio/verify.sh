#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=apparmor-q2
PROF=/sys/kernel/security/apparmor/profiles

# 1. enforce
grep -qx "k8s-nginx-ro (enforce)" "$PROF" && ok "k8s-nginx-ro em modo enforce" \
  || fail "k8s-nginx-ro não está em modo enforce ($(grep '^k8s-nginx-ro ' "$PROF" || echo 'não carregado'))"
grep -q 'complain' /etc/apparmor.d/k8s-nginx-ro && fail "o arquivo do perfil foi alterado (flag complain)" || true

# 2. enforced.txt
EXP=$(sed -n 's/^\(k8s-[^ ]*\) (enforce)$/\1/p' "$PROF" | sort -u)
GOT=$(sed 's/[[:space:]]*$//; /^$/d' /opt/course/11/q2/enforced.txt 2>/dev/null | sort -u)
[ -n "$GOT" ] && [ "$GOT" = "$EXP" ] && ok "enforced.txt correto ($(echo $EXP))" \
  || fail "enforced.txt incorreto: esperado [$(echo $EXP)], encontrado [$(echo $GOT)]"

# 3. spec do deployment
J='{.spec.template.spec.securityContext.appArmorProfile.type}|{.spec.template.spec.securityContext.appArmorProfile.localhostProfile}'
POD_T=$(kubectl -n "$NS" get deploy web -o jsonpath="$J")
cprof() {  # tipo/perfil efetivo do container $1 no spec
  local c
  c=$(kubectl -n "$NS" get deploy web -o jsonpath="{.spec.template.spec.containers[?(@.name=='$1')].securityContext.appArmorProfile.type}|{.spec.template.spec.containers[?(@.name=='$1')].securityContext.appArmorProfile.localhostProfile}")
  [ "$c" = "|" ] && echo "$POD_T" || echo "$c"
}
[ "$(cprof nginx)" = "Localhost|k8s-nginx-ro" ] && ok "container nginx com Localhost/k8s-nginx-ro" \
  || fail "container nginx com perfil '$(cprof nginx)' (esperado Localhost|k8s-nginx-ro)"
[ "$(cprof logger)" = "RuntimeDefault|" ] && ok "container logger com RuntimeDefault explícito" \
  || fail "container logger com perfil '$(cprof logger)' (esperado RuntimeDefault)"

# 4. runtime
kubectl -n "$NS" rollout status deploy/web --timeout=90s >/dev/null 2>&1 \
  && ok "Deployment web com todas as réplicas prontas" || fail "Deployment web não está pronto"

CN=$(kubectl -n "$NS" exec deploy/web -c nginx -- cat /proc/self/attr/current 2>/dev/null)
[ "$CN" = "k8s-nginx-ro (enforce)" ] && ok "nginx confinado por '$CN'" || fail "nginx confinado por '${CN:-?}'"
CL=$(kubectl -n "$NS" exec deploy/web -c logger -- cat /proc/self/attr/current 2>/dev/null)
case "$CL" in
  ""|unconfined*|k8s-*) fail "logger confinado por '${CL:-?}' (esperado perfil padrão do runtime)";;
  *) ok "logger confinado pelo perfil do runtime ('$CL')";;
esac

if kubectl -n "$NS" exec deploy/web -c nginx -- sh -c 'echo hacked > /usr/share/nginx/html/index.html' >/dev/null 2>&1; then
  fail "foi possível alterar /usr/share/nginx/html/index.html"
else
  [ -n "$CN" ] && ok "escrita em /usr/share/nginx/html negada" || fail "não foi possível testar a escrita (container indisponível)"
fi

finish
