#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MAN=/etc/kubernetes/manifests/kube-apiserver.yaml
PORT=$(grep -oE -- '--secure-port=[0-9]+' "$MAN" | cut -d= -f2); PORT=${PORT:-6443}

ANON=$(kubectl get clusterrolebindings -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{range .subjects[*]}{.name}{","}{end}{"\n"}{end}' 2>/dev/null \
  | awk -F'|' '$1!="system:public-info-viewer" && $2 ~ /(^|,)system:(anonymous|unauthenticated),/ {print $1}')
[ -z "$ANON" ] && ok "Nenhum ClusterRoleBinding extra para anônimos" || fail "Ainda existem ClusterRoleBindings para anônimos: $(echo $ANON)"

kubectl get clusterrolebinding system:public-info-viewer >/dev/null 2>&1 && ok "system:public-info-viewer preservado" || fail "system:public-info-viewer foi removido"

F=/opt/course/8/q1/removidos.txt
GOT=$(tr -d ' \r\t' < "$F" 2>/dev/null | grep -v '^$' | sort -u)
EXP=$(printf 'kubelet-debug-access\nmetrics-public-access\n')
[ "$GOT" = "$EXP" ] && ok "removidos.txt correto" || fail "removidos.txt ausente ou incorreto (encontrado: $(echo $GOT))"

[ "$(kubectl auth can-i list secrets -A --as system:anonymous --as-group system:unauthenticated 2>/dev/null)" = "yes" ] \
  && fail "Anônimos ainda podem listar secrets" || ok "Anônimos não listam secrets"

C=$(curl -sk -m 5 -o /dev/null -w '%{http_code}' "https://127.0.0.1:$PORT/api/v1/namespaces/kube-system/pods")
[ "$C" = "401" ] || [ "$C" = "403" ] && ok "Requisição anônima a pods negada (HTTP $C)" || fail "Requisição anônima a pods retornou HTTP $C"

finish
