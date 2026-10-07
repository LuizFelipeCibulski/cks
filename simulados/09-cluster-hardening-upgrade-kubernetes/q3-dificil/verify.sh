#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

W=$(worker_node)
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)

T=$(cat /opt/course/09/q3/target-version 2>/dev/null | tr -d '[:space:]')
[ -n "$T" ] || { fail "arquivo /opt/course/09/q3/target-version não encontrado — rode o setup.sh"; finish; }
T="v${T#v}"
info "Versão alvo: $T"

# 1. componentes do control plane
API=$(kubectl get --raw /version 2>/dev/null | tr ',{}' '\n\n\n' | grep '"gitVersion"' | sed -E 's/.*"(v[^"]+)".*/\1/')
[ "$API" = "$T" ] && ok "kube-apiserver em $API" || fail "kube-apiserver em '${API:-?}' (esperado $T)"
for c in kube-apiserver kube-controller-manager kube-scheduler; do
  img=$(grep -E '^\s*image:' "/etc/kubernetes/manifests/$c.yaml" 2>/dev/null | head -1 | awk '{print $2}')
  [ "${img##*:}" = "$T" ] && ok "$c manifest usa $img" || fail "$c manifest usa '${img:-?}' (esperado tag $T)"
done
KP=$(kubectl -n kube-system get ds kube-proxy -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
if [ -n "$KP" ]; then
  [ "${KP##*:}" = "$T" ] && ok "kube-proxy em ${KP##*:}" || fail "kube-proxy em '${KP##*:}' (esperado $T)"
fi

# 2/3. binários e kubelet por nó
check_node() {  # check_node <node> <cmd-prefix>
  local n=$1; shift
  local kadm kctl kl hold
  kadm=$("$@" kubeadm version -o short 2>/dev/null)
  [ "$kadm" = "$T" ] && ok "[$n] kubeadm $kadm" || fail "[$n] kubeadm '${kadm:-?}' (esperado $T)"
  kctl=$("$@" kubectl version --client 2>/dev/null | sed -n 's/^Client Version: //p')
  [ "$kctl" = "$T" ] && ok "[$n] kubectl $kctl" || fail "[$n] kubectl '${kctl:-?}' (esperado $T)"
  kl=$(kubectl get node "$n" -o jsonpath='{.status.nodeInfo.kubeletVersion}')
  [ "$kl" = "$T" ] && ok "[$n] kubelet rodando $kl" || fail "[$n] kubelet rodando '${kl:-?}' (esperado $T)"
  hold=$("$@" apt-mark showhold 2>/dev/null)
  for p in kubeadm kubelet kubectl; do
    echo "$hold" | grep -qx "$p" && ok "[$n] $p em hold" || fail "[$n] $p não está em hold"
  done
  [ "$(kubectl get node "$n" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ] \
    && ok "[$n] Ready" || fail "[$n] não está Ready"
  [ "$(kubectl get node "$n" -o jsonpath='{.spec.unschedulable}')" != "true" ] \
    && ok "[$n] schedulable" || fail "[$n] ainda cordoned"
}
check_node "$CPN" env
if [ -n "$W" ]; then
  check_node "$W" $SSH "$W"
else
  ok "cluster sem node worker — item 3 ignorado"
fi

# 5. workload
DES=$(kubectl -n upgrade-q3 get deploy critical-app -o jsonpath='{.spec.replicas}' 2>/dev/null)
AV=$(kubectl -n upgrade-q3 get deploy critical-app -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
[ -n "$DES" ] && [ "$DES" = "$AV" ] && ok "critical-app com $AV/$DES réplicas disponíveis" \
  || fail "critical-app com ${AV:-0}/${DES:-?} réplicas disponíveis"

finish
