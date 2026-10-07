#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

STATE=/var/lib/cks-sim/22-q1
D=/opt/course/22/q1
[ -f "$STATE/log-shipper.pid" ] || { echo "Estado do setup não encontrado. Rode: bash setup.sh"; exit 1; }
BADPID=$(cat "$STATE/log-shipper.pid")

clean() { tr -d '[:space:]' < "$1" 2>/dev/null; }

[ "$(clean $D/name.txt)" == "log-shipper" ] && ok "name.txt correto" || fail "name.txt incorreto ou ausente"
[ "$(clean $D/pid.txt)" == "$BADPID" ] && ok "pid.txt correto" || fail "pid.txt incorreto ou ausente"
sc=$(clean $D/syscall.txt | tr 'A-Z' 'a-z')
if [ "$sc" == "openat" ] || [ "$sc" == "open" ]; then ok "syscall.txt correto ($sc)"; else fail "syscall.txt incorreto ou ausente"; fi

if kill -0 "$BADPID" 2>/dev/null || pgrep -x log-shipper >/dev/null; then
  fail "processo log-shipper ainda está rodando"
else
  ok "processo log-shipper encerrado"
fi
[ ! -e /usr/local/bin/log-shipper ] && ok "executável /usr/local/bin/log-shipper removido" || fail "executável /usr/local/bin/log-shipper ainda existe"

for a in cache-warmer metrics-agent; do
  pid=$(cat "$STATE/$a.pid" 2>/dev/null)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then ok "$a continua rodando"; else fail "$a foi encerrado (não deveria)"; fi
done

finish
