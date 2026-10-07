#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=seccomp-q2
OUT=/opt/course/12/q2
F=/var/lib/kubelet/seccomp/profiles/block-chmod.json

# 1. perfil no kubelet
if [ -f "$F" ] && cmp -s <(tr -d '[:space:]' < "$F") <(tr -d '[:space:]' < "$OUT/block-chmod.json"); then
  ok "perfil instalado em $F"
else
  fail "perfil ausente ou diferente em $F"
fi

# 2. Pod
if ! kubectl -n "$NS" get pod hardened >/dev/null 2>&1; then
  fail "Pod hardened não existe"; finish
fi
PT=$(kubectl -n "$NS" get pod hardened -o jsonpath='{.spec.securityContext.seccompProfile.type}|{.spec.securityContext.seccompProfile.localhostProfile}')
CT=$(kubectl -n "$NS" get pod hardened -o jsonpath="{.spec.containers[?(@.name=='app')].securityContext.seccompProfile.type}|{.spec.containers[?(@.name=='app')].securityContext.seccompProfile.localhostProfile}")
[ "$CT" = "|" ] && EFF=$PT || EFF=$CT
[ "$EFF" = "Localhost|profiles/block-chmod.json" ] && ok "container app usa Localhost profiles/block-chmod.json" \
  || fail "seccompProfile efetivo do container app: '$EFF' (esperado Localhost|profiles/block-chmod.json)"

kubectl -n "$NS" wait --for=condition=Ready pod/hardened --timeout=60s >/dev/null 2>&1 \
  && ok "Pod hardened Running" || { fail "Pod hardened não está Running"; finish; }

kubectl -n "$NS" exec hardened -c app -- sh -c 'touch /tmp/verify && chmod 600 /tmp/verify' >/dev/null 2>&1 \
  && fail "chmod foi permitido dentro do container" || ok "chmod bloqueado pelo seccomp"
kubectl -n "$NS" exec hardened -c app -- sh -c 'touch /tmp/verify2 && ls /tmp >/dev/null' >/dev/null 2>&1 \
  && ok "demais syscalls funcionando (touch/ls)" || fail "operações comuns falharam no container"

# 3/4. arquivos de resposta
grep -qi 'operation not permitted' "$OUT/chmod.txt" 2>/dev/null \
  && ok "chmod.txt contém o erro" || fail "chmod.txt ausente ou sem 'Operation not permitted'"
MODE=$(tr -d '[:space:]' < "$OUT/seccomp-mode.txt" 2>/dev/null)
[ "$MODE" = "2" ] || [ "$MODE" = "Seccomp:2" ] && ok "seccomp-mode.txt correto (2)" \
  || fail "seccomp-mode.txt incorreto (encontrado: '${MODE:-vazio}')"

finish
