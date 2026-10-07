#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/19/q1

# 1) scan "antes"
if [ -s $D/kubesec-before.json ] && jq -e '.[0].score' $D/kubesec-before.json >/dev/null 2>&1; then
  sb=$(jq -r '.[0].score' $D/kubesec-before.json)
  [ "$sb" -lt 0 ] && ok "kubesec-before.json válido (score original $sb)" || fail "kubesec-before.json deveria ser o scan do arquivo ORIGINAL (score negativo); achado $sb"
else
  fail "$D/kubesec-before.json ausente ou não é a saída JSON do kubesec"
fi

# 2) IDs críticos
exp="HostNetwork HostPID Privileged"
if [ -s $D/critical.txt ]; then
  got=$(tr -d ' \r' < $D/critical.txt | grep -v '^$' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')
  [ "$got" = "$exp" ] && ok "critical.txt contém os IDs críticos corretos" || fail "critical.txt não corresponde aos IDs críticos reportados pelo kubesec (achado: $got)"
else
  fail "$D/critical.txt ausente"
fi

# 3) scan do arquivo corrigido
R=$(kubesec scan $D/pod.yaml 2>/dev/null)
score=$(echo "$R" | jq -r '.[0].score // empty')
ncrit=$(echo "$R" | jq -r '[.[0].scoring.critical[]?] | length')
[ "${ncrit:-1}" = "0" ] && ok "Nenhum item crítico no kubesec" || fail "kubesec ainda reporta $ncrit item(ns) crítico(s)"
[ -n "$score" ] && [ "$score" -ge 4 ] && ok "Score kubesec = $score (>= 4)" || fail "Score kubesec = ${score:-?} (precisa ser >= 4)"

img=$(grep -E '^\s*image:' $D/pod.yaml | awk '{print $2}' | head -1)
[ "$img" = "busybox:1.36" ] && ok "Imagem mantida" || fail "A imagem deve continuar busybox:1.36"

# 4) Pod no cluster
ph=$(kubectl -n kubesec-lab get pod legacy-agent -o jsonpath='{.status.phase}' 2>/dev/null)
[ "$ph" = "Running" ] && ok "Pod kubesec-lab/legacy-agent Running" || fail "Pod kubesec-lab/legacy-agent deveria estar Running (fase: ${ph:-inexistente})"
priv=$(kubectl -n kubesec-lab get pod legacy-agent -o jsonpath='{.spec.containers[0].securityContext.privileged}{.spec.hostPID}{.spec.hostNetwork}' 2>/dev/null)
echo "$priv" | grep -q true && fail "Pod no cluster ainda tem privileged/hostPID/hostNetwork (recriou o Pod?)" || ok "Pod no cluster sem privileged/hostPID/hostNetwork"

finish
