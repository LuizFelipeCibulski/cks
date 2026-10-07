#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=sec-ctx; P=secure-app
jp() { kubectl -n $NS get pod $P -o jsonpath="$1" 2>/dev/null; }

[ "$(jp '{.status.phase}')" = "Running" ] && ok "Pod secure-app Running" || { fail "Pod secure-app não está Running"; finish; }

uid=$(kubectl -n $NS exec $P -c app -- id -u 2>/dev/null)
gid=$(kubectl -n $NS exec $P -c app -- id -g 2>/dev/null)
groups=$(kubectl -n $NS exec $P -c app -- id -G 2>/dev/null)
[ "$uid" = "1000" ] && ok "UID 1000" || fail "UID do processo é '$uid' (esperado 1000)"
[ "$gid" = "3000" ] && ok "GID 3000" || fail "GID do processo é '$gid' (esperado 3000)"
echo " $groups " | grep -q " 2000 " && ok "grupo suplementar 2000 (fsGroup)" || fail "grupo 2000 ausente (id -G: $groups)"

[ "$(jp '{.spec.securityContext.fsGroup}')" = "2000" ] && ok "fsGroup=2000 no nível do Pod" || fail "fsGroup 2000 deve estar no securityContext do Pod"

c='{.spec.containers[?(@.name=="app")].securityContext'
[ "$(jp "$c.readOnlyRootFilesystem}")" = "true" ] && ok "readOnlyRootFilesystem=true" || fail "readOnlyRootFilesystem não é true"
[ "$(jp "$c.allowPrivilegeEscalation}")" = "false" ] && ok "allowPrivilegeEscalation=false" || fail "allowPrivilegeEscalation não é false"
jp "$c.capabilities.drop}" | grep -qi '"\?all"\?' && ok "capabilities drop ALL" || fail "capabilities.drop deve conter ALL"

if kubectl -n $NS exec $P -c app -- sh -c 'echo x > /data/verify && ls -n /data/verify' 2>/dev/null | awk '{print $4}' | grep -qx 2000; then
  ok "/data gravável e arquivos pertencem ao grupo 2000"
else fail "/data não é gravável ou o arquivo não pertence ao grupo 2000"; fi
kubectl -n $NS exec $P -c app -- sh -c 'echo x > /etc/verify' >/dev/null 2>&1 && fail "rootfs está gravável" || ok "rootfs não gravável"

f=/opt/course/14/q1/pod.yaml
grep -q "readOnlyRootFilesystem" $f && grep -q "fsGroup" $f && ok "pod.yaml atualizado" || fail "$f não foi atualizado com o securityContext"

finish
