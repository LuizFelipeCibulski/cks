#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Instalando pacotes do cenário (vsftpd, tftpd-hpa) — pode levar ~1 min..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq vsftpd tftpd-hpa >/dev/null 2>&1 \
  || { echo "Falha ao instalar vsftpd/tftpd-hpa (sem internet?)"; exit 1; }
systemctl unmask vsftpd tftpd-hpa >/dev/null 2>&1
systemctl enable --now vsftpd tftpd-hpa >/dev/null 2>&1

info "Criando usuários do cenário..."
for u in deploy-bot svc-backup ops-admin; do
  id "$u" >/dev/null 2>&1 && userdel -r "$u" >/dev/null 2>&1
done
rm -f /etc/sudoers.d/90-deploy-bot /etc/sudoers.d/90-ops-admin

useradd -m -s /bin/bash deploy-bot
usermod -aG sudo deploy-bot
echo 'deploy-bot ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-deploy-bot
chmod 440 /etc/sudoers.d/90-deploy-bot

useradd -r -m -d /var/lib/svc-backup -s /bin/bash svc-backup

useradd -m -s /bin/bash ops-admin
usermod -aG sudo ops-admin

mkdir -p /opt/course/10/q2

echo
ok "Ambiente pronto! Leia o enunciado.md"
