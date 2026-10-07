# Soluções — Reduce Attack Surface (System Hardening)

> Conceito: cada processo escutando em uma porta, cada pacote instalado e cada conta com privilégio é um
> ponto de entrada possível. No CKS isso aparece como: achar e matar processos/portas indevidas, remover
> pacotes e desabilitar serviços, e aplicar *least privilege* nas contas do host (sudo, shell, UID 0).

Ferramentas que você precisa ter "na ponta dos dedos":

| Objetivo | Comando |
|---|---|
| Quem escuta em uma porta | `ss -ltnp \| grep :PORTA` (`-l` listening, `-t` tcp, `-u` udp, `-n` numérico, `-p` processo) |
| Alternativas | `netstat -tulpn \| grep :PORTA`, `lsof -i :PORTA` |
| Caminho do binário de um PID | `ls -l /proc/<PID>/exe` ou `ps -o pid,cmd -p <PID>` |
| De qual unit systemd é o PID | `systemctl status <PID>` ou `cat /proc/<PID>/cgroup` |
| Pacote dono de um arquivo | `dpkg -S /caminho` |
| Serviços | `systemctl list-units --type=service --state=running`, `systemctl disable --now X` |
| Pacotes | `apt-get purge X` / `apt remove --purge X` |

---

## Q1 (Fácil) — processo na porta 6666

```bash
ss -ltnp | grep 6666
# LISTEN 0 1 0.0.0.0:6666 0.0.0.0:* users:(("sysmond",pid=12345,fd=3))

ls -l /proc/12345/exe
# /proc/12345/exe -> /usr/local/sbin/sysmond
echo /usr/local/sbin/sysmond > /opt/course/10/q1/binary.txt

kill -9 12345
rm -f /usr/local/sbin/sysmond

ss -ltnp | grep 6666    # nada
```

Alternativas: `lsof -i :6666`, `netstat -tlpn | grep 6666`, `fuser -n tcp 6666` e depois `fuser -k -n tcp 6666`.

Por que olhar `/proc/<PID>/exe` e não só o nome em `ss`: o nome mostrado (`comm`) é limitado a 15 caracteres e
pode ser falsificado; `/proc/PID/exe` é o link real para o binário executado. Use `ps -ef | grep` apenas como
complemento (o `cmdline` também pode ser falso).

Pegadinhas:

- Apagar o binário **sem matar** o processo: ele continua rodando a partir do inode aberto
  (`/proc/PID/exe -> ... (deleted)`) e a porta continua aberta.
- Matar e não apagar: no exame a questão normalmente pede as duas coisas.

---

## Q2 (Médio) — serviços, pacotes e contas

```bash
# 1. vsftpd: parar e desabilitar, sem desinstalar
systemctl disable --now vsftpd        # equivale a stop + disable
systemctl is-enabled vsftpd           # disabled
systemctl is-active vsftpd            # inactive
# (systemctl mask vsftpd também é aceito — impede até start manual/por dependência)

# 2. tftpd-hpa: remover com arquivos de configuração
apt-get purge -y tftpd-hpa            # ou: apt remove --purge tftpd-hpa
dpkg -l | grep tftpd                  # nada (ou 'rc' = removido mas com config → faltou purge)

# 3. deploy-bot sem sudo
id deploy-bot                         # ... 27(sudo)
gpasswd -d deploy-bot sudo            # ou: deluser deploy-bot sudo
grep -r deploy-bot /etc/sudoers /etc/sudoers.d/
rm /etc/sudoers.d/90-deploy-bot
sudo -l -U deploy-bot                 # "User deploy-bot is not allowed to run sudo"

# 4. svc-backup sem shell
usermod -s /usr/sbin/nologin svc-backup
getent passwd svc-backup

# 5. ops-admin: não mexer
sudo -l -U ops-admin                  # (ALL : ALL) ALL
```

Por que: um serviço desabilitado mas instalado ainda é superfície (alguém pode iniciá-lo), mas às vezes o
negócio exige mantê-lo; `disable --now` garante que ele não volta no boot. Pacotes não usados devem sair
por completo (`purge`) para não deixar configs/credenciais esquecidas. Contas de serviço não precisam de
shell interativo e contas de automação não precisam de root.

Pegadinhas:

- `systemctl stop` sozinho **não** impede o serviço de subir no próximo boot; `disable` sozinho não para o
  processo atual. Use `disable --now`.
- `apt remove` deixa o pacote no estado `rc` (config-files). O pedido "incluindo arquivos de configuração"
  exige `purge`.
- O sudo vem de **dois lugares**: grupo `sudo` (regra `%sudo ALL=(ALL:ALL) ALL` em `/etc/sudoers`) e arquivos
  em `/etc/sudoers.d/`. Remover só um deles não basta. Sempre confirme com `sudo -l -U <user>`.
- Remover o usuário (`userdel`) viola o requisito "continuar existindo".
- Edite sudoers com `visudo` (ou apague o arquivo inteiro do `sudoers.d`); erro de sintaxe no sudoers pode
  quebrar o sudo de todo mundo.

---

## Q3 (Difícil) — host comprometido

### 1. Porta 31337 (serviço systemd que se reinicia)

```bash
ss -ltnp | grep -E ':31337|:4444'
# LISTEN ... *:31337 ... users:(("kthreadd",pid=2100,fd=3))
# LISTEN ... *:4444  ... users:(("sshd",pid=2200,fd=3))

ls -l /proc/2100/exe              # /var/lib/.cache/kthreadd   (nome de thread do kernel, mas é um arquivo!)
systemctl status 2100             # mostra a unit dona do PID: node-health.service
kill -9 2100; sleep 3; ss -ltnp | grep 31337   # voltou com outro PID → Restart=always

systemctl cat node-health         # ExecStart=/var/lib/.cache/kthreadd -dlk 31337, Restart=always
systemctl disable --now node-health
rm /etc/systemd/system/node-health.service
systemctl daemon-reload
rm -f /var/lib/.cache/kthreadd
```

### 2. Porta 4444 (respawn via cron)

```bash
ls -l /proc/2200/exe              # /dev/shm/.x/sshd   (sshd de verdade fica em /usr/sbin/sshd!)
cat /proc/2200/cgroup             # cron.service / session → não é unit própria
kill 2200; sleep 70; ss -ltnp | grep 4444    # volta após ~1 min → agendamento

grep -r -e 4444 -e /dev/shm /etc/cron* /var/spool/cron 2>/dev/null
# /etc/cron.d/logrotate-check:* * * * * root ss -ltn | grep -q ':4444 ' || setsid /dev/shm/.x/sshd ...
rm /etc/cron.d/logrotate-check
pkill -f /dev/shm/.x/sshd
rm -rf /dev/shm/.x
```

Remova a persistência **antes** de matar o processo — senão ele volta enquanto você investiga.

### 3. Shell SUID escondido

```bash
find / -xdev -type f -perm -4000 2>/dev/null       # -xdev: não desce em /proc, /sys...
find /tmp /var/tmp /dev/shm /opt /usr/local /var/lib -type f -perm -4000 2>/dev/null
# /var/tmp/.font-unix/dbus-launch
dpkg -S /var/tmp/.font-unix/dbus-launch            # "no path found" → não pertence a pacote
ls -l /var/tmp/.font-unix/dbus-launch              # -rwsr-xr-x root root ... (s = SUID)
cmp /var/tmp/.font-unix/dbus-launch /bin/bash && echo "é uma cópia do bash"
rm -f /var/tmp/.font-unix/dbus-launch
```

Um bash SUID-root vira root com `./dbus-launch -p`. Para listar SUIDs legítimos, compare com `dpkg -S`.

### 4. UID 0 duplicado

```bash
awk -F: '$3==0' /etc/passwd
# root:x:0:0:root:/root:/bin/bash
# sysbackup:x:0:0:system backup:/root:/bin/bash

userdel sysbackup
# userdel: user sysbackup is currently used by process 1   ← todo processo de root "é" UID 0
# forma mais segura: editar os arquivos diretamente
vipw        # apague a linha do sysbackup
vipw -s     # apague a linha do sysbackup no /etc/shadow
# (ou: sed -i '/^sysbackup:/d' /etc/passwd /etc/shadow)
# userdel -f sysbackup também funciona — mas NUNCA use -r: o home dele é /root!
awk -F: '$3==0' /etc/passwd     # só root
```

### 5. intern sem sudo

```bash
sudo -l -U intern
#   (root) NOPASSWD: /usr/bin/find      ← find -exec /bin/sh \; = root shell (GTFOBins)
grep -r intern /etc/sudoers /etc/sudoers.d/
rm /etc/sudoers.d/50-intern
id intern                               # confira que não está no grupo sudo também
sudo -l -U intern                       # not allowed
```

### 6. Relatório

```bash
cat > /opt/course/10/q3/report.txt <<EOF
/var/lib/.cache/kthreadd
/dev/shm/.x/sshd
/var/tmp/.font-unix/dbus-launch
EOF
```

Pegadinhas da Q3:

- `kill` em processo com `Restart=always` → o systemd sobe outro em 2s. Sempre descubra o **pai/dono**
  (`systemctl status <PID>`, `ps -o ppid= -p <PID>`, `pstree -p`).
- Desabilitar a unit mas não apagar o arquivo: o requisito pedia remover. Lembre do `daemon-reload`.
- Nomes enganosos (`kthreadd`, `sshd`, `dbus-launch`) são usados de propósito. Threads de kernel
  aparecem entre colchetes no `ps` (`[kthreadd]`) e não têm `/proc/PID/exe`.
- `/dev/shm` é tmpfs: some no reboot, mas o cron recriaria se o binário estivesse em disco — remova os dois.
- `userdel -r` no usuário com UID 0/home `/root` apaga o home do root.
- Não pare o `cron` inteiro para "resolver" — ele é serviço legítimo; remova só a entrada maliciosa.

Validação manual:

```bash
ss -ltnp | grep -E '31337|4444'; sleep 70; ss -ltnp | grep -E '31337|4444'   # nada nas duas
awk -F: '$3==0' /etc/passwd
sudo -l -U intern
find / -xdev -type f -perm -4000 2>/dev/null | xargs -r dpkg -S 2>&1 | grep 'no path'
```

Docs: https://kubernetes.io/docs/concepts/security/ (na prova, as man pages do sistema são sua referência
para `ss`, `systemctl`, `find`).
