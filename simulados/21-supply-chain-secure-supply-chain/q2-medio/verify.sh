#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# 1/2 - objetos existem
if kubectl get validatingadmissionpolicy trusted-registries >/dev/null 2>&1; then
  ok "ValidatingAdmissionPolicy trusted-registries existe"
else
  fail "ValidatingAdmissionPolicy trusted-registries não encontrada"
fi

if kubectl get validatingadmissionpolicybinding trusted-registries-binding >/dev/null 2>&1; then
  ok "ValidatingAdmissionPolicyBinding trusted-registries-binding existe"
  pn=$(kubectl get validatingadmissionpolicybinding trusted-registries-binding -o jsonpath='{.spec.policyName}')
  [ "$pn" == "trusted-registries" ] && ok "binding aponta para a policy trusted-registries" || fail "binding.spec.policyName='$pn'"
  acts=$(kubectl get validatingadmissionpolicybinding trusted-registries-binding -o jsonpath='{.spec.validationActions}')
  [[ "$acts" == *Deny* ]] && ok "validationActions contém Deny" || fail "validationActions não contém Deny ($acts)"
else
  fail "ValidatingAdmissionPolicyBinding trusted-registries-binding não encontrado"
fi

# 3 - labels
[ "$(kubectl get ns team-blue -o jsonpath='{.metadata.labels.registry-policy}')" == "enforced" ] \
  && ok "namespace team-blue tem label registry-policy=enforced" \
  || fail "namespace team-blue sem label registry-policy=enforced"
[ -z "$(kubectl get ns team-green -o jsonpath='{.metadata.labels.registry-policy}')" ] \
  && ok "namespace team-green não está marcado" \
  || fail "namespace team-green não deveria ter o label registry-policy"

# Testes de comportamento (server-side dry-run passa pela admissão)
sleep 2
pod_yaml() { # nome ns imagem [imagem-init]
  cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $1
  namespace: $2
spec:
$( [ -n "$4" ] && printf '  initContainers:\n  - name: init\n    image: %s\n' "$4")
  containers:
  - name: c
    image: $3
EOF
}
try() { pod_yaml "$@" | kubectl create --dry-run=server -f - 2>&1; }

out=$(try t1 team-blue nginx:1.27-alpine)
if [[ "$out" == *"image registry not trusted"* ]]; then ok "team-blue: nginx:1.27-alpine negado com a mensagem correta"
elif [[ "$out" == *denied* || "$out" == *forbidden* ]]; then fail "team-blue: negado mas mensagem diferente: $out"
else fail "team-blue: imagem não confiável foi aceita ($out)"; fi

out=$(try t2 team-blue docker.io/library/busybox:1.36)
[[ "$out" == *"image registry not trusted"* ]] && ok "team-blue: docker.io/library/busybox negado" || fail "team-blue: docker.io/library/busybox deveria ser negado"

out=$(try t3 team-blue registry.k8s.io.evil.com/pause:3.10)
[[ "$out" == *"image registry not trusted"* ]] && ok "team-blue: registry.k8s.io.evil.com negado (prefixo com /)" || fail "team-blue: registry.k8s.io.evil.com/... deveria ser negado (cuidado com o prefixo sem '/')"

out=$(try t4 team-blue registry.k8s.io/pause:3.10)
[[ "$out" == *created* ]] && ok "team-blue: registry.k8s.io/pause:3.10 permitido" || fail "team-blue: registry.k8s.io deveria ser permitido ($out)"

out=$(try t5 team-blue registry.cks.local:5000/app:1.0)
[[ "$out" == *created* ]] && ok "team-blue: registry.cks.local:5000/app:1.0 permitido" || fail "team-blue: registry.cks.local:5000 deveria ser permitido ($out)"

out=$(try t6 team-blue registry.k8s.io/pause:3.10 busybox:1.36)
[[ "$out" == *"image registry not trusted"* ]] && ok "team-blue: initContainer com imagem não confiável negado" || fail "team-blue: initContainer busybox:1.36 deveria ser negado ($out)"

out=$(try t7 team-green nginx:1.27-alpine)
[[ "$out" == *created* ]] && ok "team-green: não é afetado pela policy" || fail "team-green não deveria ser afetado ($out)"

# 4 - violações
F=/opt/course/21/q2/violations.txt
expected="cache
legacy
metrics-proxy
web-frontend"
if [ -f "$F" ]; then
  got=$(sed 's/#.*//; s/^pod\///; s/^team-blue\///; s/[[:space:]]//g' "$F" | grep -v '^$' | sort -u)
  if [ "$got" == "$expected" ]; then ok "violations.txt correto"
  else fail "violations.txt incorreto. Encontrado: $(echo $got)"; fi
else
  fail "arquivo $F não existe"
fi

n=$(kubectl -n team-blue get pod --no-headers 2>/dev/null | wc -l)
[ "$n" -ge 6 ] && ok "Pods existentes em team-blue não foram apagados" || fail "Pods de team-blue foram apagados (eram 6, há $n)"

finish
