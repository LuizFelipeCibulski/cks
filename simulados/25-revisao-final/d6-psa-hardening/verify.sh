#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

[ "$(kubectl get ns d6 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" = restricted ] \
  && ok "namespace d6 com enforce=restricted" || fail "label pod-security.kubernetes.io/enforce=restricted ausente"

kubectl -n d6 get pod legacy-root >/dev/null 2>&1 && fail "Pod legacy-root ainda existe" || ok "legacy-root removido"
others=$(kubectl -n d6 get pods -l 'app!=web' -o name)
[ -z "$others" ] && ok "só Pods do web no namespace" || fail "Pods extras no namespace: $others"

st=$(kubectl -n d6 get deploy web -o jsonpath='{.status.replicas}/{.status.readyReplicas}/{.status.updatedReplicas}')
[ "$st" = "2/2/2" ] && ok "web 2/2 pronto e atualizado" || fail "web não está 2/2 pronto (replicas/ready/updated = $st)"

kubectl -n d6 get sa web-sa >/dev/null 2>&1 && ok "SA web-sa existe" || fail "SA web-sa não existe"
for p in $(kubectl -n d6 get pods -l app=web -o name); do
  sa=$(kubectl -n d6 get "$p" -o jsonpath='{.spec.serviceAccountName}')
  ro=$(kubectl -n d6 get "$p" -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}')
  vols=$(kubectl -n d6 get "$p" -o jsonpath='{.spec.volumes[*].name}')
  j() { kubectl -n d6 get "$p" -o jsonpath="$1"; }
  nonroot="$(j '{.spec.securityContext.runAsNonRoot}{.spec.containers[0].securityContext.runAsNonRoot}')"
  seccomp="$(j '{.spec.securityContext.seccompProfile.type}{.spec.containers[0].securityContext.seccompProfile.type}')"
  ape=$(j '{.spec.containers[0].securityContext.allowPrivilegeEscalation}')
  drop=$(j '{.spec.containers[0].securityContext.capabilities.drop}')
  echo "$nonroot" | grep -q true && ok "$p runAsNonRoot" || fail "$p sem runAsNonRoot: true"
  echo "$seccomp" | grep -Eq 'RuntimeDefault|Localhost' && ok "$p com seccompProfile" || fail "$p sem seccompProfile RuntimeDefault"
  [ "$ape" = false ] && ok "$p allowPrivilegeEscalation=false" || fail "$p sem allowPrivilegeEscalation: false"
  echo "$drop" | grep -q ALL && ok "$p drop ALL" || fail "$p sem capabilities.drop: [ALL]"
  [ "$sa" = web-sa ] && ok "$p usa web-sa" || fail "$p usa a SA '$sa'"
  [ "$ro" = true ] && ok "$p com readOnlyRootFilesystem" || fail "$p sem readOnlyRootFilesystem: true"
  echo "$vols" | grep -q kube-api-access && fail "$p está com o token da SA montado" || ok "$p sem token montado"
done
kubectl -n d6 exec deploy/web -- wget -qO- -T3 localhost:8080 2>/dev/null | grep -qi nginx && ok "nginx responde em :8080" || fail "nginx não responde em localhost:8080"
kubectl -n d6 exec deploy/web -- touch /etc/x >/dev/null 2>&1 && fail "consegui escrever em /etc (root FS não é read-only)" || ok "root FS read-only"
finish
