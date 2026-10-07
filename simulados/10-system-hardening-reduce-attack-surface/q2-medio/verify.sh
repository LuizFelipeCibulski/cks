#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

pkg_status() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null; }

# 1. vsftpd
[ "$(pkg_status vsftpd)" = "install ok installed" ] && ok "vsftpd continua instalado" || fail "vsftpd foi desinstalado (não deveria)"
systemctl is-active --quiet vsftpd && fail "vsftpd ainda está ativo" || ok "vsftpd parado"
EN=$(systemctl is-enabled vsftpd 2>/dev/null)
case "$EN" in
  enabled|enabled-runtime|static|alias|indirect) fail "vsftpd ainda habilitado no boot ($EN)";;
  *) ok "vsftpd não sobe no boot (${EN:-desconhecido})";;
esac
ss -ltn '( sport = :21 )' | grep -q LISTEN && fail "algo ainda escuta na porta 21/tcp" || ok "porta 21/tcp fechada"

# 2. tftpd-hpa
ST=$(pkg_status tftpd-hpa)
case "$ST" in
  "install ok installed") fail "tftpd-hpa ainda está instalado";;
  *config-files*) fail "tftpd-hpa removido mas arquivos de configuração permanecem (faltou purge)";;
  *) ok "tftpd-hpa removido completamente";;
esac
ss -lun '( sport = :69 )' | grep -q ':69' && fail "algo ainda escuta na porta 69/udp" || ok "porta 69/udp fechada"

# 3. deploy-bot
if id deploy-bot >/dev/null 2>&1; then
  ok "usuário deploy-bot existe"
  id -nG deploy-bot | tr ' ' '\n' | grep -Eqx 'sudo|admin|wheel' && fail "deploy-bot ainda está em grupo administrativo (sudo/admin/wheel)" || ok "deploy-bot fora dos grupos administrativos"
  if sudo -l -U deploy-bot 2>&1 | grep -q 'not allowed'; then ok "deploy-bot sem permissões de sudo"
  else fail "deploy-bot ainda pode usar sudo (veja 'sudo -l -U deploy-bot')"; fi
else
  fail "usuário deploy-bot foi removido (deveria continuar existindo)"
fi

# 4. svc-backup
SH=$(getent passwd svc-backup | cut -d: -f7)
case "$SH" in
  /usr/sbin/nologin|/sbin/nologin|/bin/false|/usr/bin/false) ok "svc-backup sem shell interativo ($SH)";;
  "") fail "usuário svc-backup não existe";;
  *) fail "svc-backup ainda tem shell $SH";;
esac

# 5. ops-admin
if id -nG ops-admin 2>/dev/null | tr ' ' '\n' | grep -qx sudo && ! sudo -l -U ops-admin 2>&1 | grep -q 'not allowed'; then
  ok "ops-admin mantém acesso sudo"
else
  fail "ops-admin perdeu o acesso sudo"
fi

finish
