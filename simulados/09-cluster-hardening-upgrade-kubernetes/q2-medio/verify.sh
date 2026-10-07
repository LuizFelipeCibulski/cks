#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

W=$(worker_node)
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)

[ -n "$W" ] || { fail "cluster sem node worker — questão não aplicável"; finish; }

CPV=$(dpkg-query -W -f='${Version}' kubeadm 2>/dev/null)     # ex: 1.35.1-1.1
CPK=$(kubectl get node "$CP" -o jsonpath='{.status.nodeInfo.kubeletVersion}')  # ex: v1.35.1
WANT="v${CPV%%-*}"
info "Versão alvo: pacotes $CPV / $WANT"

for p in kubeadm kubelet kubectl; do
  v=$($SSH "$W" "dpkg-query -W -f='\${Version}' $p" 2>/dev/null)
  [ "$v" = "$CPV" ] && ok "pacote $p no $W = $v" || fail "pacote $p no $W = '${v:-?}' (esperado $CPV)"
done

KADM=$($SSH "$W" "kubeadm version -o short" 2>/dev/null)
[ "$KADM" = "$WANT" ] && ok "kubeadm no $W reporta $KADM" || fail "kubeadm no $W reporta '${KADM:-?}' (esperado $WANT)"

KCTL=$($SSH "$W" "kubectl version --client 2>/dev/null | sed -n 's/^Client Version: //p'" 2>/dev/null)
[ "$KCTL" = "$WANT" ] && ok "kubectl no $W reporta $KCTL" || fail "kubectl no $W reporta '${KCTL:-?}' (esperado $WANT)"

WK=$(kubectl get node "$W" -o jsonpath='{.status.nodeInfo.kubeletVersion}')
[ "$WK" = "$CPK" ] && ok "kubelet do $W rodando $WK (igual ao controlplane)" \
  || fail "kubelet do $W reporta $WK, controlplane $CPK (reiniciou o kubelet?)"

HOLD=$($SSH "$W" "apt-mark showhold" 2>/dev/null)
for p in kubeadm kubelet kubectl; do
  echo "$HOLD" | grep -qx "$p" && ok "$p em hold no $W" || fail "$p não está em hold no $W"
done

READY=$(kubectl get node "$W" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
[ "$READY" = "True" ] && ok "$W Ready" || fail "$W não está Ready"
[ "$(kubectl get node "$W" -o jsonpath='{.spec.unschedulable}')" != "true" ] \
  && ok "$W aceitando pods (uncordon)" || fail "$W ainda está cordoned"

CPNOW=$(kubectl get --raw /version 2>/dev/null | tr ',{}' '\n\n\n' | grep '"gitVersion"' | sed -E 's/.*"(v[^"]+)".*/\1/')
[ "$CPNOW" = "$CPK" ] && ok "controlplane mantido em $CPNOW" || fail "versão do apiserver ($CPNOW) difere do kubelet do controlplane ($CPK)"

finish
