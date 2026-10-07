#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

SVC=node-health
SVC_BIN=/var/lib/.cache/kthreadd
CRON_BIN=/dev/shm/.x/sshd
SUID_BIN=/var/tmp/.font-unix/dbus-launch
REPORT=/opt/course/10/q3/report.txt

# 1. portas e persistência
for p in 31337 4444; do
  ss -ltn "( sport = :$p )" | grep -q LISTEN && fail "algo ainda escuta na porta $p" || ok "porta $p fechada"
done

systemctl is-active --quiet "$SVC" 2>/dev/null && fail "serviço $SVC ainda ativo" || ok "serviço $SVC parado"
UNIT=$(systemctl show -p FragmentPath --value "$SVC" 2>/dev/null)
if [ -n "$UNIT" ] && [ -e "$UNIT" ]; then
  fail "arquivo de unit do $SVC ainda existe ($UNIT)"
else
  ok "unit $SVC removida"
fi
ls /etc/systemd/system/*.wants/"$SVC".service >/dev/null 2>&1 && fail "symlink de enable do $SVC ainda existe" || ok "sem symlink de enable para $SVC"

if grep -rqsE '/dev/shm/\.x|:4444' /etc/cron.d /etc/crontab /var/spool/cron /etc/cron.hourly /etc/cron.daily 2>/dev/null; then
  fail "ainda há agendamento cron que relança o processo da porta 4444"
else
  ok "sem agendamento cron malicioso"
fi
systemctl is-active --quiet cron && ok "serviço cron legítimo continua ativo" || fail "o serviço cron foi parado (não deveria)"

# 2/3. binários
for b in "$SVC_BIN" "$CRON_BIN" "$SUID_BIN"; do
  [ -e "$b" ] && fail "binário $b ainda existe" || ok "binário $b removido"
done
pgrep -f "$SVC_BIN|$CRON_BIN" >/dev/null && fail "processo malicioso ainda em execução" || ok "nenhum processo malicioso em execução"

# 4. UID 0
UID0=$(awk -F: '$3==0{print $1}' /etc/passwd | grep -vx root)
[ -z "$UID0" ] && ok "apenas root tem UID 0" || fail "usuários com UID 0 além de root: $(echo $UID0)"
[ "$(awk -F: '$1=="root"{print $3}' /etc/passwd)" = "0" ] && ok "root intacto" || fail "o usuário root foi alterado!"

# 5. intern
if id intern >/dev/null 2>&1; then
  ok "usuário intern existe"
  sudo -l -U intern 2>&1 | grep -q 'not allowed' && ok "intern sem permissões de sudo" \
    || fail "intern ainda pode usar sudo (veja 'sudo -l -U intern')"
else
  fail "usuário intern foi removido (deveria continuar existindo)"
fi

# 6. relatório
if [ -f "$REPORT" ]; then
  for b in "$SVC_BIN" "$CRON_BIN" "$SUID_BIN"; do
    grep -qxF "$b" <(sed 's/[[:space:]]*$//' "$REPORT") && ok "report.txt contém $b" || fail "report.txt não contém $b"
  done
else
  fail "$REPORT não encontrado"
fi

# serviços legítimos
for s in kubelet containerd; do
  systemctl is-active --quiet "$s" && ok "$s ativo" || fail "$s não está ativo!"
done

finish
