# Reduce Attack Surface — Q2 (Médio)

**Domínio:** System Hardening (10%) — *Minimize host OS footprint; minimize IAM roles (least privilege)*
**Tempo sugerido:** ~7 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

Uma auditoria do host `controlplane` encontrou serviços de rede legados e contas com privilégios além do
necessário. Aplique o princípio do menor privilégio e reduza a superfície de ataque.

## Tarefa

1. O serviço **FTP** (`vsftpd`) ainda será usado por outro time no futuro: **não desinstale** o pacote, mas
   garanta que o serviço esteja parado e **não suba novamente** após um reboot.
2. O servidor **TFTP** (pacote `tftpd-hpa`) não é mais necessário: remova o pacote **completamente**,
   incluindo seus arquivos de configuração.
3. O usuário `deploy-bot` é uma conta de automação e **não deve poder executar nenhum comando como root via
   `sudo`**. O usuário deve continuar existindo.
4. A conta de serviço `svc-backup` não deve ter shell de login interativo (use `/usr/sbin/nologin`).
5. O usuário `ops-admin` é o administrador oficial do host e **deve manter** seu acesso `sudo`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/security/
- `man systemctl`, `man apt-get`, `man usermod`, `man gpasswd`, `man sudoers`

Quando terminar: `bash verify.sh`
