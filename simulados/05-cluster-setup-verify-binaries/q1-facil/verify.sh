#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/5/q1
STATE=/var/lib/cks-sim
BAD=$(cat "$STATE/05-q1.ans" 2>/dev/null)
[ -z "$BAD" ] && { fail "Estado do setup não encontrado. Rode setup.sh primeiro."; finish; }

ANS=$(tr -d ' \r\n\t' < "$D/adulterado.txt" 2>/dev/null)
if [ "$ANS" = "$BAD" ]; then ok "adulterado.txt identifica corretamente o binário adulterado"
else fail "adulterado.txt ausente ou incorreto (conteúdo: '${ANS}')"; fi

if [ -e "$D/$BAD" ]; then fail "O binário adulterado ainda existe em $D"
else ok "Binário adulterado removido"; fi

[ -f "$D/sha512sums.txt" ] && ok "sha512sums.txt mantido" || fail "sha512sums.txt foi removido"

for b in kubectl kubeadm kubelet; do
  [ "$b" = "$BAD" ] && continue
  exp=$(awk -v n="$b" '$2==n{print $1}' "$STATE/05-q1.sums")
  if [ -f "$D/$b" ] && [ "$(sha512sum "$D/$b" | awk '{print $1}')" = "$exp" ]; then
    ok "Binário íntegro $b mantido"
  else
    fail "Binário íntegro $b foi removido ou alterado"
  fi
done

finish
