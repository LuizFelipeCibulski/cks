#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=frontend
J() { kubectl -n $NS get deploy web -o jsonpath="$1" 2>/dev/null; }

for c in nginx content; do
  [ "$(J "{.spec.template.spec.containers[?(@.name==\"$c\")].securityContext.readOnlyRootFilesystem}")" == "true" ] \
    && ok "container $c com readOnlyRootFilesystem: true" || fail "container $c sem readOnlyRootFilesystem: true"
done

[ -n "$(J '{.spec.template.spec.volumes[?(@.name=="html")].emptyDir}')" ] && ok "volume html mantido" || fail "volume html foi removido/alterado"

# todos os volumes do Pod devem ser emptyDir (ou projected do SA)
nonempty=$(kubectl -n $NS get deploy web -o go-template='{{range .spec.template.spec.volumes}}{{if not .emptyDir}}{{.name}} {{end}}{{end}}')
[ -z "$nonempty" ] && ok "todos os volumes são emptyDir" || fail "volumes que não são emptyDir: $nonempty"

bad=""
while read -r mp; do
  [ -z "$mp" ] && continue
  case "${mp%/}" in
    ""|/etc|/usr|/var|/bin|/sbin|/lib|/etc/nginx) bad="$bad $mp" ;;
  esac
done < <(J '{range .spec.template.spec.containers[*]}{range .volumeMounts[*]}{.mountPath}{"\n"}{end}{end}')
[ -z "$bad" ] && ok "nenhum volume montado em diretórios proibidos" || fail "volume montado em diretório proibido:$bad"

if kubectl -n $NS rollout status deploy/web --timeout=90s >/dev/null 2>&1; then ok "rollout concluído"; else fail "rollout não concluído (Pods quebrando?)"; fi
ready=$(J '{.status.readyReplicas}')
[ "${ready:-0}" == "$(J '{.spec.replicas}')" ] && ok "todas as réplicas Ready ($ready)" || fail "réplicas Ready: ${ready:-0}"

POD=$(kubectl -n $NS get pod -l app=web -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{if eq .status.phase "Running"}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}{{end}}' 2>/dev/null | head -1)
if [ -n "$POD" ]; then
  for c in nginx content; do
    kubectl -n $NS exec "$POD" -c $c -- touch /cks-test >/dev/null 2>&1 \
      && fail "container $c consegue escrever em /" || ok "container $c: / é somente leitura"
  done
  page=""
  for _ in 1 2 3 4; do
    page=$(kubectl -n $NS exec "$POD" -c nginx -- wget -qO- -T 3 http://127.0.0.1/ 2>/dev/null)
    [[ "$page" == *"generated at"* ]] && break
    sleep 4
  done
  [[ "$page" == *"generated at"* ]] && ok "nginx serve o conteúdo gerado pelo container content" \
    || fail "nginx não está servindo a página gerada (veja: kubectl -n $NS logs $POD -c content)"
else
  fail "nenhum Pod Running do Deployment web"
fi

finish
