#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

D=/opt/course/5/q3
STATE=/var/lib/cks-sim
[ -f "$STATE/05-q3.ans" ] || { fail "Estado do setup não encontrado. Rode setup.sh primeiro."; finish; }

norm() { tr -d '\r' | sed -E 's/[[:space:]]+//g' | tr '[:lower:]' '[:upper:]' | grep -v '^$' | sort; }
if [ -f "$D/resultado.txt" ]; then
  for comp in kube-apiserver kubelet kubectl; do
    exp=$(grep "^$comp:" "$STATE/05-q3.ans" | norm)
    got=$(grep -iE "^[[:space:]]*$comp[[:space:]]*:" "$D/resultado.txt" | norm)
    [ "$got" = "$exp" ] && ok "resultado.txt: $comp correto" || fail "resultado.txt: linha de $comp incorreta ou ausente"
  done
else
  fail "$D/resultado.txt não existe"
fi

hash -r
KPATH=$(readlink -f "$(command -v kubectl)")
if [ "$(sha512sum "$KPATH" | awk '{print $1}')" = "$(cat "$STATE/05-q3.kubectl.sha512")" ]; then
  ok "kubectl em uso ($KPATH) confere com o binário oficial"
else
  fail "kubectl em uso ($KPATH) ainda não confere com o binário oficial"
fi
[ -x "$KPATH" ] && ok "kubectl é executável" || fail "kubectl não é executável"

KL_BIN=$(readlink -f "/proc/$(pgrep -xo kubelet)/exe" 2>/dev/null)
if grep -q '^kubelet: OK' "$STATE/05-q3.ans"; then
  [ "$(sha512sum "$KL_BIN" 2>/dev/null | awk '{print $1}')" = "$(cat "$STATE/05-q3.kubelet.sha512")" ] \
    && ok "kubelet íntegro mantido" || fail "kubelet em uso não confere mais com o oficial"
fi

kubectl get --raw=/readyz >/dev/null 2>&1 && ok "kube-apiserver respondendo" || fail "kube-apiserver não responde"
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
[ "$CP" = "True" ] && ok "node controlplane Ready" || fail "node controlplane não está Ready"

finish
