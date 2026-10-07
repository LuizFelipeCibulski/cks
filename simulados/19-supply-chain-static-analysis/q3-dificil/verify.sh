#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

F=/opt/course/19/q3/deploy.yaml
NS=static-app
IMG=nginxinc/nginx-unprivileged:1.27-alpine

# 1) kube-linter
if kube-linter lint "$F" >/tmp/kl.out 2>&1; then ok "kube-linter: nenhum erro"
else fail "kube-linter ainda reporta erros:"; grep -oE '\(check: [a-z-]+' /tmp/kl.out | sort | uniq -c | sed 's/^/     /'; fi

# 2) kubesec
R=$(kubesec scan "$F" 2>/dev/null)
dep=$(echo "$R" | jq -c '[.[] | select(.object|startswith("Deployment/"))][0]')
score=$(echo "$dep" | jq -r '.score // empty')
ncrit=$(echo "$dep" | jq -r '[.scoring.critical[]?] | length')
[ "$ncrit" = "0" ] && ok "kubesec: nenhum item crítico no Deployment" || fail "kubesec: $ncrit item(ns) crítico(s) no Deployment"
[ -n "$score" ] && [ "$score" -ge 10 ] && ok "kubesec: score do Deployment = $score (>= 10)" || fail "kubesec: score do Deployment = ${score:-?} (precisa >= 10)"

# 3) imagem / réplicas no arquivo e no cluster
grep -qE "image:\s*\"?$IMG\"?\s*$" "$F" && ok "Arquivo usa $IMG" || fail "Arquivo deveria usar a imagem $IMG"
cimg=$(kubectl -n $NS get deploy catalog -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$cimg" = "$IMG" ] && ok "Deployment no cluster usa $IMG" || fail "Deployment no cluster usa '$cimg' (aplicou o arquivo?)"
rep=$(kubectl -n $NS get deploy catalog -o jsonpath='{.spec.replicas}' 2>/dev/null)
rdy=$(kubectl -n $NS get deploy catalog -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
upd=$(kubectl -n $NS get deploy catalog -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
[ "$rep" = "2" ] && [ "$rdy" = "2" ] && [ "$upd" = "2" ] && ok "Deployment catalog 2/2 prontas" || fail "Deployment catalog deveria ter 2/2 réplicas prontas e atualizadas (spec=$rep ready=${rdy:-0} updated=${upd:-0})"

# 4) segredo
envj=$(kubectl -n $NS get deploy catalog -o json 2>/dev/null | jq -c '.spec.template.spec.containers[].env[]? | select(.name=="API_SECRET")')
if echo "$envj" | jq -e '.valueFrom.secretKeyRef.name=="catalog-api" and .valueFrom.secretKeyRef.key=="api-secret"' >/dev/null 2>&1; then
  ok "API_SECRET vem do Secret catalog-api/api-secret"
else
  fail "API_SECRET deveria vir de secretKeyRef catalog-api / api-secret (achado: ${envj:-ausente})"
fi
grep -q 's3cr3t-4p1-k3y-2024' <(kubectl -n $NS get deploy catalog -o yaml 2>/dev/null) && fail "O valor do segredo ainda aparece no Deployment"
kubectl -n $NS get secret catalog-api -o jsonpath='{.data.api-secret}' 2>/dev/null | grep -q . \
  && ok "Secret static-app/catalog-api com a chave api-secret existe" || fail "Secret static-app/catalog-api com a chave api-secret não encontrado"

# 5) Service respondendo
pod=$(kubectl -n $NS get pod -l app=catalog --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$pod" ] && kubectl -n $NS exec "$pod" -- wget -qO- -T3 http://catalog.static-app.svc.cluster.local:80 2>/dev/null | grep -qi nginx; then
  ok "Service catalog:80 responde HTTP"
else
  fail "Service catalog:80 não responde (targetPort aponta para a porta certa?)"
fi

# 6) arquivo final do kubesec
J=/opt/course/19/q3/kubesec-final.json
fs=$(jq -r '[.[] | select(.object|startswith("Deployment/"))][0].score // empty' $J 2>/dev/null)
[ -n "$fs" ] && [ "$fs" -ge 10 ] && ok "kubesec-final.json válido (score $fs)" || fail "$J ausente/inválido ou não corresponde ao arquivo corrigido"

finish
