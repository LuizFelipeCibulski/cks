#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
source "$(dirname "$(readlink -f "$0")")/../lib/gvisor.sh"
require_root
require_controlplane

T=$(cat /opt/course/16/q3/target-node.txt 2>/dev/null); [ -n "$T" ] || T=$(target_node)
echo "Nó alvo: $T"

st=$(on_node "$T" status 2>/dev/null)
echo "$st" | grep -q "registrado: sim" && ok "handler runsc registrado no containerd de $T" || fail "handler runsc não encontrado no config.toml de $T"
[ "$(kubectl get node "$T" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ] && ok "$T Ready" || fail "$T não está Ready"
[ "$(kubectl get node "$T" -o jsonpath='{.metadata.labels.sandbox\.cks\.io/runtime}')" = "gvisor" ] && ok "label sandbox.cks.io/runtime=gvisor em $T" || fail "$T sem a label sandbox.cks.io/runtime=gvisor"
others=$(kubectl get nodes -l sandbox.cks.io/runtime=gvisor --no-headers -o custom-columns=N:.metadata.name | grep -vx "$T")
[ -z "$others" ] && ok "label apenas no nó alvo" || fail "outros nós têm a label (não têm gVisor!): $others"

[ "$(kubectl get runtimeclass gvisor-sandbox -o jsonpath='{.handler}' 2>/dev/null)" = "runsc" ] && ok "RuntimeClass gvisor-sandbox handler runsc" || fail "RuntimeClass gvisor-sandbox (handler runsc) ausente"
[ "$(kubectl get runtimeclass gvisor-sandbox -o jsonpath='{.scheduling.nodeSelector.sandbox\.cks\.io/runtime}' 2>/dev/null)" = "gvisor" ] \
  && ok "RuntimeClass com scheduling.nodeSelector sandbox.cks.io/runtime=gvisor" || fail "RuntimeClass sem scheduling.nodeSelector sandbox.cks.io/runtime: gvisor"

for d in gateway processor reports; do
  if ! kubectl -n payments get deploy $d >/dev/null 2>&1; then fail "Deployment $d não existe (não delete, corrija)"; continue; fi
  rc=$(kubectl -n payments get deploy $d -o jsonpath='{.spec.template.spec.runtimeClassName}')
  [ "$rc" = "gvisor-sandbox" ] && ok "$d usa gvisor-sandbox" || fail "$d não usa runtimeClassName gvisor-sandbox"
  IFS=/ read -r rd up sp <<< "$(kubectl -n payments get deploy $d -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}/{.spec.replicas}')"
  [ -n "$rd" ] && [ "$rd" = "$sp" ] && [ "$up" = "$sp" ] && ok "$d com $rd/$sp réplicas prontas" || fail "$d sem todas as réplicas prontas/atualizadas (ready=$rd updated=$up spec=$sp)"
  for p in $(kubectl -n payments get pod -l app=$d --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}'); do
    node=$(kubectl -n payments get pod $p -o jsonpath='{.spec.nodeName}')
    [ "$node" = "$T" ] || fail "Pod $p rodando em $node (esperado $T)"
    kubectl -n payments exec $p -- dmesg 2>/dev/null | grep -qi gvisor || fail "Pod $p não está no gVisor"
  done
done
bad=$(kubectl -n payments get pods --no-headers --field-selector=status.phase!=Failed 2>/dev/null | grep -vE 'Running|Terminating')
[ -z "$bad" ] && ok "Nenhum Pod com erro em payments" || fail "Pods com problema em payments:
$bad"

f=/opt/course/16/q3/dmesg.txt
[ -s $f ] && grep -qi gvisor $f && ok "dmesg.txt mostra o kernel do gVisor" || fail "$f ausente ou sem a saída do dmesg do gVisor"

# Pod comum (runc) continua funcionando no nó alvo
kubectl -n default delete pod runc-probe --ignore-not-found --wait=true >/dev/null 2>&1
kubectl -n default run runc-probe --image=busybox:1.36 --restart=Never \
  --overrides="{\"spec\":{\"nodeName\":\"$T\",\"tolerations\":[{\"operator\":\"Exists\"}]}}" -- sleep 60 >/dev/null 2>&1
if kubectl -n default wait --for=condition=Ready pod/runc-probe --timeout=90s >/dev/null 2>&1; then
  kubectl -n default exec runc-probe -- dmesg 2>/dev/null | grep -qi gvisor && fail "Pod sem RuntimeClass está rodando no gVisor (runtime padrão alterado?)" || ok "Pod comum (runc) funciona em $T"
else
  fail "Pod comum (sem RuntimeClass) não sobe em $T — o runtime runc foi quebrado?"
fi
kubectl -n default delete pod runc-probe --wait=false >/dev/null 2>&1

finish
