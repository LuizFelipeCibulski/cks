#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

kubectl get --raw=/readyz >/dev/null 2>&1 && ok "kube-apiserver respondendo" || { fail "kube-apiserver não responde"; finish; }

# ---------- Parte A
[ "$(kubectl get ns checkout -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = "restricted" ] \
  && ok "checkout: enforce=restricted" || fail "checkout: label enforce=restricted ausente"
v=$(kubectl get ns checkout -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}')
[ -z "$v" ] || [ "$v" = "latest" ] && ok "checkout: versão latest" || fail "checkout: enforce-version deveria ser latest (atual: $v)"

f=/opt/course/13/q3/reason.txt
if [ -s $f ] && grep -qi "violates PodSecurity" $f && grep -qi "restricted" $f; then ok "reason.txt contém o erro do PSA"; else fail "$f deve conter a mensagem 'forbidden: violates PodSecurity \"restricted:latest\"...' do evento do ReplicaSet"; fi

ready=$(kubectl -n checkout get deploy checkout-api -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
upd=$(kubectl -n checkout get deploy checkout-api -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
[ "$ready" = "2" ] && [ "$upd" = "2" ] && ok "checkout-api com 2/2 réplicas prontas e atualizadas" || fail "checkout-api não tem 2 réplicas prontas/atualizadas (ready=$ready updated=$upd)"

# Todos os pods atuais do namespace são compatíveis com restricted? O PSA só avalia os pods existentes
# quando a política muda, por isso o dry-run troca a versão (v1.33) para forçar a avaliação.
warn=$(kubectl label --dry-run=server --overwrite ns checkout pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.33 2>&1 | grep -i "violate")
[ -z "$warn" ] && ok "Nenhum Pod em checkout viola restricted" || fail "Ainda há Pods violando restricted: $warn"

spec=$(kubectl -n checkout get deploy checkout-api -o json)
echo "$spec" | grep -q '"hostPath"' && fail "Deployment ainda usa hostPath" || ok "Sem hostPath"
vols=$(kubectl -n checkout get deploy checkout-api -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}={.emptyDir}{"\n"}{end}')
echo "$vols" | grep -q '^logs=' && ok "Volume 'logs' mantido (emptyDir)" || fail "Volume 'logs' deveria existir como emptyDir"
mp=$(kubectl -n checkout get deploy checkout-api -o jsonpath='{.spec.template.spec.containers[?(@.name=="api")].volumeMounts[?(@.name=="logs")].mountPath}')
[ "$mp" = "/var/log/app" ] && ok "mountPath /var/log/app mantido" || fail "mountPath do volume logs deveria ser /var/log/app"

pod=$(kubectl -n checkout get pod -l app=checkout-api --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$pod" ] && kubectl -n checkout exec "$pod" -c api -- wget -qO- -T3 http://127.0.0.1:8080 2>/dev/null | grep -qi nginx; then
  ok "Aplicação responde na porta 8080"
else fail "Aplicação não respondeu HTTP na 8080"; fi
if [ -n "$pod" ]; then
  uid=$(kubectl -n checkout exec "$pod" -c api -- id -u 2>/dev/null)
  [ -n "$uid" ] && [ "$uid" != "0" ] && ok "Container api roda com UID $uid (não-root)" || fail "Container api roda como root"
fi

# ---------- Parte B
CFG=/etc/kubernetes/psa/podsecurity.yaml
if [ -f $CFG ] && grep -q "kind: *AdmissionConfiguration" $CFG && grep -q "name: *PodSecurity" $CFG && grep -q "PodSecurityConfiguration" $CFG; then
  ok "$CFG existe com AdmissionConfiguration/PodSecurity"
else fail "$CFG ausente ou inválido"; fi

flag=$(ps -eo args | grep '[k]ube-apiserver ' | grep -oE -- '--admission-control-config-file=[^ ]+' | cut -d= -f2)
[ "$flag" = "$CFG" ] && ok "kube-apiserver usa --admission-control-config-file=$CFG" || fail "kube-apiserver não está com --admission-control-config-file=$CFG (atual: '$flag')"

out=$(kubectl -n legacy-batch run psa-probe --image=busybox:1.36 --dry-run=server --overrides='{"spec":{"containers":[{"name":"psa-probe","image":"busybox:1.36","command":["sleep","1"],"securityContext":{"privileged":true}}]}}' 2>&1)
echo "$out" | grep -q "created (server dry run)" && ok "legacy-batch isento: pod privilegiado aceito" || fail "legacy-batch não está isento (saída: $out)"
[ "$(kubectl get ns legacy-batch -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = "restricted" ] \
  && ok "legacy-batch manteve a label enforce=restricted" || fail "A label enforce=restricted de legacy-batch foi alterada/removida"

kubectl create ns psa-default-probe >/dev/null 2>&1
out=$(kubectl -n psa-default-probe run p --image=busybox:1.36 --dry-run=server --overrides='{"spec":{"hostPID":true}}' -- sleep 1 2>&1)
kubectl delete ns psa-default-probe --wait=false >/dev/null 2>&1
if echo "$out" | grep -q "created (server dry run)" && echo "$out" | grep -q "would violate PodSecurity \"baseline:latest\""; then
  ok "Defaults: namespace sem labels aceita (enforce privileged) e avisa baseline"
else fail "Defaults do PodSecurity não conferem (esperado aceitar com warning baseline:latest). Saída: $out"; fi

ls /etc/kubernetes/manifests | grep -E 'apiserver' | grep -vx 'kube-apiserver.yaml' | grep -q . \
  && fail "Há arquivos extras em /etc/kubernetes/manifests (backups ali viram static pods!)" || ok "/etc/kubernetes/manifests limpo"

finish
