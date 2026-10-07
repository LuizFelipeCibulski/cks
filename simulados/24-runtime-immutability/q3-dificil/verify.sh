#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

BAD="lyra/backend lyra/frontend orion/cache orion/scheduler pegasus/batch pegasus/worker"
GOOD="orion/api pegasus/metrics pegasus/db lyra/static"

# 1 - arquivo
F=/opt/course/24/q3/pods.txt
if [ -f "$F" ]; then
  got=$(sed 's/#.*//; s/[[:space:]]//g; s#/pod/#/#' "$F" | grep -v '^$' | sort -u | tr '\n' ' ')
  [ "$got" == "$BAD " ] && ok "pods.txt correto" || fail "pods.txt incorreto (lido: $got)"
else
  fail "$F não existe"
fi

alive() { # existe e não está terminando
  local ts
  ts=$(kubectl -n "${1%/*}" get pod "${1#*/}" -o jsonpath='{.metadata.deletionTimestamp}{"|"}{.metadata.name}' 2>/dev/null) || return 1
  [[ "$ts" == "|"* ]]
}

# 2 - remoção
for p in $BAD; do
  [ "$p" == "lyra/frontend" ] && continue   # é recriado no item 4
  alive "$p" && fail "$p ainda existe" || ok "$p removido"
done
for p in $GOOD; do
  ph=$(kubectl -n "${p%/*}" get pod "${p#*/}" -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$ph" == "Running" ] && alive "$p" && ok "$p (imutável) continua rodando" || fail "$p deveria continuar rodando"
done

# 3 - VAP
kubectl get validatingadmissionpolicy require-readonly-rootfs >/dev/null 2>&1 && ok "ValidatingAdmissionPolicy existe" || fail "ValidatingAdmissionPolicy require-readonly-rootfs não encontrada"
if kubectl get validatingadmissionpolicybinding require-readonly-rootfs-binding >/dev/null 2>&1; then
  ok "ValidatingAdmissionPolicyBinding existe"
  [ "$(kubectl get validatingadmissionpolicybinding require-readonly-rootfs-binding -o jsonpath='{.spec.policyName}')" == "require-readonly-rootfs" ] \
    || fail "binding não referencia a policy require-readonly-rootfs"
  [[ "$(kubectl get validatingadmissionpolicybinding require-readonly-rootfs-binding -o jsonpath='{.spec.validationActions}')" == *Deny* ]] \
    || fail "binding sem validationActions Deny"
else
  fail "ValidatingAdmissionPolicyBinding require-readonly-rootfs-binding não encontrado"
fi

try() { # ns ro_main(true/false/none) ro_init(true/false/none/absent)
  local sc_main="" sc_init="" init=""
  [ "$2" != none ] && sc_main="    securityContext: {readOnlyRootFilesystem: $2}"
  if [ "$3" != absent ]; then
    [ "$3" != none ] && sc_init="    securityContext: {readOnlyRootFilesystem: $3}"
    init="  initContainers:
  - name: init
    image: busybox:1.36
$sc_init"
  fi
  cat <<EOF | kubectl create --dry-run=server -f - 2>&1
apiVersion: v1
kind: Pod
metadata: {name: vap-test, namespace: $1}
spec:
$init
  containers:
  - name: c
    image: busybox:1.36
$sc_main
EOF
}
sleep 1
out=$(try lyra none absent);  [[ "$out" == *"readOnlyRootFilesystem required"* ]] && ok "lyra: Pod sem securityContext negado" || fail "lyra: Pod sem securityContext deveria ser negado ($out)"
out=$(try lyra false absent); [[ "$out" == *"readOnlyRootFilesystem required"* ]] && ok "lyra: readOnlyRootFilesystem=false negado" || fail "lyra: readOnlyRootFilesystem=false deveria ser negado"
out=$(try lyra true none);    [[ "$out" == *"readOnlyRootFilesystem required"* ]] && ok "lyra: initContainer sem readOnlyRootFilesystem negado" || fail "lyra: initContainer sem readOnlyRootFilesystem deveria ser negado"
out=$(try lyra true true);    [[ "$out" == *created* ]] && ok "lyra: Pod com todos os containers read-only permitido" || fail "lyra: Pod read-only deveria ser permitido ($out)"
out=$(try lyra true absent);  [[ "$out" == *created* ]] && ok "lyra: Pod sem initContainers e read-only permitido" || fail "lyra: Pod read-only sem init deveria ser permitido ($out)"
out=$(try orion none absent); [[ "$out" == *created* ]] && ok "orion: não é afetado pela policy" || fail "orion não deveria ser afetado ($out)"

# 4 - frontend recriado e imutável
if alive lyra/frontend && [ "$(kubectl -n lyra get pod frontend -o jsonpath='{.status.phase}')" == "Running" ]; then
  ok "lyra/frontend recriado e Running"
  for c in app log-agent; do
    ro=$(kubectl -n lyra get pod frontend -o jsonpath="{.spec.containers[?(@.name==\"$c\")].securityContext.readOnlyRootFilesystem}")
    pr=$(kubectl -n lyra get pod frontend -o jsonpath="{.spec.containers[?(@.name==\"$c\")].securityContext.privileged}")
    uid=$(kubectl -n lyra exec frontend -c $c -- id -u 2>/dev/null)
    [ "$ro" == "true" ] && [ "$pr" != "true" ] && [ -n "$uid" ] && [ "$uid" != "0" ] \
      && ok "frontend/$c imutável (ro=$ro, uid=$uid)" || fail "frontend/$c não é imutável (ro=$ro privileged=${pr:-false} uid=$uid)"
  done
  kubectl -n lyra exec frontend -c log-agent -- touch /cks-test >/dev/null 2>&1 && fail "log-agent ainda escreve em /" || ok "log-agent: / é somente leitura"
  a=$(kubectl -n lyra exec frontend -c log-agent -- wc -l /tmp/agent.log 2>/dev/null | awk '{print $1}')
  sleep 6
  b=$(kubectl -n lyra exec frontend -c log-agent -- wc -l /tmp/agent.log 2>/dev/null | awk '{print $1}')
  [ -n "$b" ] && [ "${b:-0}" -gt "${a:-0}" ] && ok "log-agent continua gravando /tmp/agent.log" || fail "log-agent não está gravando /tmp/agent.log"
else
  fail "lyra/frontend não existe ou não está Running"
fi

finish
