#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

BIN=/usr/local/sbin/sysmond
PORT=6666
F=/opt/course/10/q1/binary.txt

ANS=$(head -1 "$F" 2>/dev/null | tr -d '[:space:]')
[ "$ANS" = "$BIN" ] && ok "binary.txt aponta para $BIN" || fail "binary.txt incorreto ou ausente (encontrado: '${ANS:-vazio}')"

ss -ltn "( sport = :$PORT )" | grep -q LISTEN \
  && fail "ainda há processo escutando na porta $PORT" \
  || ok "nada escutando na porta TCP $PORT"

pgrep -f "$BIN" >/dev/null && fail "o processo $BIN ainda está rodando" || ok "processo encerrado"

[ -e "$BIN" ] && fail "o binário $BIN ainda existe" || ok "binário removido do disco"

finish
