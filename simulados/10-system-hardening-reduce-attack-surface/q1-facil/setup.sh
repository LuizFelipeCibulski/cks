#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

BIN=/usr/local/sbin/sysmond
PORT=6666
OUT=/opt/course/10/q1

# netcat-openbsd é usado como "binário malicioso" (suporta -k / -d)
if ! command -v nc.openbsd >/dev/null; then
  info "Instalando netcat-openbsd..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq netcat-openbsd >/dev/null 2>&1
fi
SRC=$(readlink -f "$(command -v nc.openbsd)")
[ -x "$SRC" ] || { echo "Não foi possível instalar netcat-openbsd"; exit 1; }

info "Limpando tentativas anteriores..."
pkill -f "$BIN" 2>/dev/null; sleep 1
rm -rf "$OUT"; mkdir -p "$OUT"

info "Preparando cenário..."
cp "$SRC" "$BIN"; chmod 755 "$BIN"
touch -d '2024-03-11 03:12' "$BIN"
setsid nohup "$BIN" -dlk "$PORT" >/dev/null 2>&1 < /dev/null &
sleep 1
ss -ltn "( sport = :$PORT )" | grep -q LISTEN || { echo "falha ao iniciar o cenário"; exit 1; }

echo
ok "Ambiente pronto! Leia o enunciado.md"
