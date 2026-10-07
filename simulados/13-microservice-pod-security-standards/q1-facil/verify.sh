#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

lbl() { kubectl get ns team-blue -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$1}" 2>/dev/null; }

[ "$(lbl enforce)" = "baseline" ] && ok "enforce=baseline" || fail "label pod-security.kubernetes.io/enforce=baseline ausente em team-blue"
[ "$(lbl enforce-version)" = "latest" ] && ok "enforce-version=latest" || fail "label pod-security.kubernetes.io/enforce-version=latest ausente"
[ "$(lbl warn)" = "restricted" ] && ok "warn=restricted" || fail "label pod-security.kubernetes.io/warn=restricted ausente"

# Teste de comportamento: pod privilegiado deve ser barrado pelo admission
out=$(kubectl apply -f /opt/course/13/q1/pod.yaml --dry-run=server 2>&1)
if echo "$out" | grep -qi "violates PodSecurity"; then ok "Pod privilegiado é rejeitado pelo PSA"; else fail "Pod privilegiado NÃO foi rejeitado (saída: $out)"; fi

kubectl -n team-blue get pod node-debugger >/dev/null 2>&1 && fail "Pod node-debugger existe (não deveria ter sido criado)" || ok "Pod node-debugger não existe"

f=/opt/course/13/q1/error.txt
if [ -s $f ] && grep -qi "forbidden" $f && grep -qi "baseline" $f; then ok "$f contém o erro do PSA"; else fail "$f não contém a mensagem de erro (esperado 'forbidden ... violates PodSecurity \"baseline:latest\"')"; fi

[ "$(kubectl -n team-blue get pod inventory -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] && ok "Pod inventory continua rodando" || fail "Pod inventory não está Running"

finish
