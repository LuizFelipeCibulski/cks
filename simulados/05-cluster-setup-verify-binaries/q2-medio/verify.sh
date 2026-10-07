#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/5/q2
STATE=/var/lib/cks-sim
[ -f "$STATE/05-q2.ans" ] || { fail "Estado do setup não encontrado. Rode setup.sh primeiro."; finish; }
KVER=$(cat "$STATE/05-q2.ver")

V=$(tr -d ' \r\n\t' < "$D/versao.txt" 2>/dev/null)
[ "${V#v}" = "${KVER#v}" ] && ok "versao.txt correto ($KVER)" || fail "versao.txt ausente ou incorreto (esperado $KVER, encontrado '$V')"

GOT=$(tr -d ' \r\t' < "$D/adulterados.txt" 2>/dev/null | grep -v '^$' | sed 's#.*/##' | sort -u)
if [ -n "$GOT" ] && [ "$GOT" = "$(cat "$STATE/05-q2.ans")" ]; then
  ok "adulterados.txt lista exatamente os binários adulterados"
else
  fail "adulterados.txt ausente ou incorreto (encontrado: $(echo $GOT))"
fi

while read -r b; do
  [ -f "$D/quarentena/$b" ] && ok "$b está em quarentena/" || fail "$b não está em $D/quarentena/"
  [ -e "$D/$b" ] && fail "$b (adulterado) ainda está em $D/" || ok "$b removido de $D/"
done < "$STATE/05-q2.ans"

for b in kubectl kubeadm kubelet kube-proxy; do
  grep -qx "$b" "$STATE/05-q2.ans" && continue
  exp=$(awk -v n="$b" '$2==n{print $1}' "$STATE/05-q2.sums")
  if [ -f "$D/$b" ] && [ "$(sha512sum "$D/$b" | awk '{print $1}')" = "$exp" ]; then
    ok "Binário íntegro $b mantido em $D/"
  else
    fail "Binário íntegro $b não está em $D/ (ou foi alterado)"
  fi
done

finish
