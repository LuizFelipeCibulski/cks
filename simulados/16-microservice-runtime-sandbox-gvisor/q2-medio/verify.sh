#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

f=/opt/course/16/q2/runtimeclass.txt
[ -f $f ] && [ "$(tr -d ' \n\r' < $f)" = "secure-runtime" ] && ok "runtimeclass.txt correto" || fail "$f ausente ou incorreto"
[ "$(kubectl get runtimeclass secure-runtime -o jsonpath='{.handler}' 2>/dev/null)" = "runsc" ] && ok "RuntimeClass secure-runtime intacta" || fail "RuntimeClass secure-runtime foi alterada/removida"
n=$(kubectl get runtimeclass --no-headers 2>/dev/null | wc -l)
[ "$n" -le 3 ] && ok "nenhuma RuntimeClass nova criada" || fail "não crie novas RuntimeClasses (existem $n)"

for d in scanner uploader thumbnailer; do
  rc=$(kubectl -n untrusted get deploy $d -o jsonpath='{.spec.template.spec.runtimeClassName}' 2>/dev/null)
  [ "$rc" = "secure-runtime" ] && ok "$d usa secure-runtime" || fail "$d não usa runtimeClassName secure-runtime (atual: '$rc')"
  r=$(kubectl -n untrusted get deploy $d -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}/{.spec.replicas}' 2>/dev/null)
  IFS=/ read -r rd up sp <<< "$r"
  [ -n "$rd" ] && [ "$rd" = "$sp" ] && [ "$up" = "$sp" ] && ok "$d com réplicas prontas ($r)" || fail "$d sem todas as réplicas prontas/atualizadas ($r)"
  kubectl -n untrusted exec deploy/$d -- dmesg 2>/dev/null | grep -qi gvisor && ok "$d roda no gVisor (dmesg)" || fail "$d não está rodando no gVisor"
done
extra=$(kubectl -n untrusted get deploy --no-headers -o custom-columns=N:.metadata.name | grep -vxE 'scanner|uploader|thumbnailer')
[ -z "$extra" ] || fail "Deployments inesperados em untrusted: $extra"

f=/opt/course/16/q2/dmesg.txt
[ -s $f ] && grep -qi gvisor $f && ok "dmesg.txt mostra o kernel do gVisor" || fail "$f ausente ou não contém a saída do dmesg do gVisor"

rc=$(kubectl -n trusted get deploy portal -o jsonpath='{.spec.template.spec.runtimeClassName}' 2>/dev/null)
r=$(kubectl -n trusted get deploy portal -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ -z "$rc" ] && [ "$r" = "1" ] && ok "portal continua no runtime padrão e pronto" || fail "portal deveria continuar sem runtimeClassName e pronto (rc='$rc' ready='$r')"

finish
