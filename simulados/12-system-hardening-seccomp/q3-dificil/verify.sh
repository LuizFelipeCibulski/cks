#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=seccomp-q3
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
W=$(worker_node)
T=${W:-$CPN}
on_t() { if [ "$T" = "$CPN" ]; then bash -c "$*"; else $SSH "$T" "$*"; fi; }
info "Nó alvo: $T"

# 1. kubelet seccompDefault
CFGZ=$(kubectl get --raw "/api/v1/nodes/$T/proxy/configz" 2>/dev/null)
echo "$CFGZ" | grep -q '"seccompDefault":true' \
  && ok "kubelet do $T com seccompDefault=true (configz)" || fail "kubelet do $T não está com seccompDefault habilitado (reiniciou o kubelet?)"
on_t "grep -Eq '^seccompDefault:[[:space:]]*true' /var/lib/kubelet/config.yaml" \
  && ok "seccompDefault: true no /var/lib/kubelet/config.yaml" || fail "seccompDefault: true não encontrado em /var/lib/kubelet/config.yaml do $T"
[ "$(kubectl get node "$T" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ] \
  && ok "$T Ready" || fail "$T não está Ready"

# 2. perfil
PJ=$(on_t "cat /var/lib/kubelet/seccomp/profiles/no-mkdir.json" 2>/dev/null)
if [ -z "$PJ" ]; then
  fail "perfil /var/lib/kubelet/seccomp/profiles/no-mkdir.json não encontrado no $T"
else
  R=$(echo "$PJ" | python3 -c '
import json,sys
try:
    p=json.load(sys.stdin)
except Exception:
    print("json-invalido"); sys.exit()
blocked=set()
for s in p.get("syscalls",[]):
    if s.get("action","").startswith("SCMP_ACT_ERRNO") or s.get("action")=="SCMP_ACT_KILL" or s.get("action","").startswith("SCMP_ACT_KILL"):
        blocked.update(s.get("names",[]))
print(p.get("defaultAction"), ",".join(sorted(blocked)))
' 2>/dev/null)
  case "$R" in
    json-invalido) fail "perfil instalado não é um JSON válido";;
    "SCMP_ACT_ALLOW mkdir,mkdirat") ok "perfil correto: ALLOW por padrão, bloqueia apenas mkdir/mkdirat";;
    *) fail "perfil incorreto (defaultAction / syscalls bloqueadas = '$R'; esperado 'SCMP_ACT_ALLOW mkdir,mkdirat')";;
  esac
fi

# 3. builder
J=$(kubectl -n "$NS" get deploy builder -o jsonpath='{.spec.template.spec.nodeSelector}{.spec.template.spec.nodeName}{.spec.template.spec.affinity.nodeAffinity}' 2>/dev/null)
if echo "$J" | grep -q "$T"; then ok "Deployment builder restrito ao $T"
elif [ -n "$J" ]; then ok "Deployment builder com restrição de nó (label customizado) — conferindo pods abaixo"
else fail "Deployment builder não está restrito ao $T (nodeSelector/nodeName/nodeAffinity)"; fi

PT=$(kubectl -n "$NS" get deploy builder -o jsonpath='{.spec.template.spec.securityContext.seccompProfile.type}|{.spec.template.spec.securityContext.seccompProfile.localhostProfile}')
CT=$(kubectl -n "$NS" get deploy builder -o jsonpath="{.spec.template.spec.containers[?(@.name=='builder')].securityContext.seccompProfile.type}|{.spec.template.spec.containers[?(@.name=='builder')].securityContext.seccompProfile.localhostProfile}")
[ "$CT" = "|" ] && EFF=$PT || EFF=$CT
[ "$EFF" = "Localhost|profiles/no-mkdir.json" ] && ok "container builder com Localhost profiles/no-mkdir.json" \
  || fail "seccompProfile efetivo do builder: '$EFF'"

kubectl -n "$NS" rollout status deploy/builder --timeout=90s >/dev/null 2>&1
RDY=$(kubectl -n "$NS" get deploy builder -o jsonpath='{.status.readyReplicas}')
[ "$RDY" = "2" ] && ok "builder 2/2 prontos" || fail "builder com ${RDY:-0}/2 prontos"
NODES=$(kubectl -n "$NS" get pods -l app=builder --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u)
[ -n "$NODES" ] && [ "$NODES" = "$T" ] && ok "pods do builder apenas em $T" || fail "pods do builder em: $(echo ${NODES:-nenhum})"

if [ "$RDY" = "2" ]; then
  kubectl -n "$NS" exec deploy/builder -c builder -- mkdir /tmp/verify-dir >/dev/null 2>&1 \
    && fail "mkdir permitido no builder" || ok "mkdir bloqueado no builder"
  kubectl -n "$NS" exec deploy/builder -c builder -- touch /tmp/verify-file >/dev/null 2>&1 \
    && ok "touch funciona no builder" || fail "touch falhou no builder (perfil bloqueando demais?)"
fi

# 4. plain
if kubectl -n "$NS" get pod plain >/dev/null 2>&1; then
  S=$(kubectl -n "$NS" get pod plain -o jsonpath='{.spec.securityContext.seccompProfile}{.spec.containers[*].securityContext.seccompProfile}')
  [ -z "$S" ] && ok "Pod plain sem seccompProfile no spec" || fail "Pod plain declara seccompProfile no spec (não era permitido)"
  [ "$(kubectl -n "$NS" get pod plain -o jsonpath='{.spec.nodeName}')" = "$T" ] && ok "Pod plain no $T" || fail "Pod plain não está no $T"
  kubectl -n "$NS" wait --for=condition=Ready pod/plain --timeout=60s >/dev/null 2>&1 && ok "Pod plain Running" || fail "Pod plain não está Running"
  MODE=$(kubectl -n "$NS" exec plain -- cat /proc/1/status 2>/dev/null | awk '/^Seccomp:/{print $2}')
  [ "$MODE" = "2" ] && ok "Pod plain com filtro seccomp ativo (Seccomp: 2)" \
    || fail "Pod plain com Seccomp: '${MODE:-?}' (o padrão só vale para containers criados após a mudança no kubelet)"
else
  fail "Pod plain não existe"
fi

finish
