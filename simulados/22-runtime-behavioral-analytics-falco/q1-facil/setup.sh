#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

STATE=/var/lib/cks-sim/22-q1
AGENTS="cache-warmer log-shipper metrics-agent"

if ! command -v strace >/dev/null; then
  info "Instalando strace..."
  apt-get install -y strace >/dev/null 2>&1 || { apt-get update -qq >/dev/null; apt-get install -y strace >/dev/null 2>&1; }
fi

info "Limpando execuções anteriores..."
for a in $AGENTS; do pkill -x "$a" 2>/dev/null; done
sleep 1
rm -rf /opt/course/22/q1 "$STATE"
mkdir -p /opt/course/22/q1 "$STATE"

# Cada "agente" é uma cópia do bash com nome próprio executando um loop.
# O loop é passado por stdin (não fica em disco nem no cmdline).
for a in $AGENTS; do cp /bin/bash "/usr/local/bin/$a"; chmod 755 "/usr/local/bin/$a"; done

start_agent() {
  local name=$1 body=$2
  local f; f=$(mktemp)
  printf '%s\n' "$body" > "$f"
  setsid "/usr/local/bin/$name" -s < "$f" >/dev/null 2>&1 &
  sleep 0.5
  rm -f "$f"
  pgrep -xo "$name" > "$STATE/$name.pid"
}

start_agent cache-warmer 'while true; do read -r _ < /etc/hostname; read -r _ < /proc/loadavg; sleep 2; done'
start_agent log-shipper  'while true; do read -r _ < /etc/os-release; read -r _ < /etc/shadow; read -r _ < /proc/uptime; sleep 2; done'
start_agent metrics-agent 'while true; do read -r _ < /proc/meminfo; read -r _ < /etc/passwd; sleep 2; done'

sleep 1
for a in $AGENTS; do
  pgrep -x "$a" >/dev/null || { echo "Falha ao iniciar $a"; exit 1; }
done

echo
ok "Ambiente pronto! Leia o enunciado.md"
