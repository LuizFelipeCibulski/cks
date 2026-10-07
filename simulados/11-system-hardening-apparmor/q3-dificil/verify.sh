#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=apparmor-q3
P=k8s-deny-upload
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
W=$(worker_node)
T=${W:-$CPN}
on_node() { if [ "$T" = "$CPN" ]; then bash -c "$*"; else $SSH "$T" "$*"; fi; }
info "Nó alvo: $T"

# 1. label
[ "$(kubectl get node "$T" -o jsonpath='{.metadata.labels.security}')" = "apparmor" ] \
  && ok "$T com label security=apparmor" || fail "$T sem label security=apparmor"
OTHERS=$(kubectl get nodes -l security=apparmor --no-headers -o custom-columns=N:.metadata.name | grep -vx "$T")
[ -z "$OTHERS" ] && ok "nenhum outro nó com o label" || fail "outros nós também têm security=apparmor: $(echo $OTHERS)"

# 2. perfil carregado e persistente
on_node "grep -qx '$P (enforce)' /sys/kernel/security/apparmor/profiles" \
  && ok "perfil $P carregado em enforce no $T" || fail "perfil $P não está carregado em enforce no $T"
on_node "grep -ls 'profile $P ' /etc/apparmor.d/* 2>/dev/null | grep -q ." \
  && ok "perfil persistido em /etc/apparmor.d no $T" || fail "perfil não encontrado em /etc/apparmor.d no $T (não sobrevive a reboot)"

# 3. deployment
SEL=$(kubectl -n "$NS" get deploy uploader -o jsonpath='{.spec.template.spec.nodeSelector.security}')
AFF=$(kubectl -n "$NS" get deploy uploader -o jsonpath='{.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}')
if [ "$SEL" = "apparmor" ] || echo "$AFF" | grep -q '"security"'; then
  ok "Deployment restrito a nós com security=apparmor"
else
  fail "Deployment não restringe o agendamento por security=apparmor (nodeSelector/nodeAffinity)"
fi

POD_P=$(kubectl -n "$NS" get deploy uploader -o jsonpath='{.spec.template.spec.securityContext.appArmorProfile.localhostProfile}')
CON_P=$(kubectl -n "$NS" get deploy uploader -o jsonpath='{.spec.template.spec.containers[0].securityContext.appArmorProfile.localhostProfile}')
EFF=${CON_P:-$POD_P}
[ "$EFF" = "$P" ] && ok "Deployment usa localhostProfile $P" || fail "Deployment usa localhostProfile '${EFF:-nenhum}' (esperado o nome do perfil definido no arquivo)"

kubectl -n "$NS" rollout status deploy/uploader --timeout=90s >/dev/null 2>&1
RDY=$(kubectl -n "$NS" get deploy uploader -o jsonpath='{.status.readyReplicas}')
[ "$RDY" = "2" ] && ok "uploader 2/2 prontos" || fail "uploader com ${RDY:-0}/2 réplicas prontas"

NODES=$(kubectl -n "$NS" get pods -l app=uploader --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u)
[ -n "$NODES" ] && [ "$NODES" = "$T" ] && ok "pods rodando apenas em $T" || fail "pods rodando em: $(echo ${NODES:-nenhum})"

# 4. comportamento
CUR=$(kubectl -n "$NS" exec deploy/uploader -- cat /proc/self/attr/current 2>/dev/null)
[ "$CUR" = "$P (enforce)" ] && ok "container confinado por '$CUR'" || fail "container confinado por '${CUR:-?}'"
if [ -n "$CUR" ]; then
  kubectl -n "$NS" exec deploy/uploader -- touch /uploads/verify-test >/dev/null 2>&1 \
    && fail "escrita em /uploads permitida" || ok "escrita em /uploads negada"
  kubectl -n "$NS" exec deploy/uploader -- touch /tmp/verify-test >/dev/null 2>&1 \
    && ok "escrita em /tmp permitida" || fail "escrita em /tmp foi negada (perfil/Deployment errado?)"
fi
grep -qi 'permission denied' /opt/course/11/q3/write-test.txt 2>/dev/null \
  && ok "write-test.txt contém o erro do touch" || fail "write-test.txt ausente ou sem a mensagem 'Permission denied'"

finish
