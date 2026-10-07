# Reduce Attack Surface — Q3 (Difícil)

**Domínio:** System Hardening (10%) — *Minimize host OS footprint; minimize IAM roles; minimize external access to the network*
**Tempo sugerido:** ~12 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

O host `controlplane` foi comprometido. Um scanner externo detectou as portas **TCP 31337** e **TCP 4444**
abertas, e o time de resposta a incidentes suspeita que o atacante deixou mecanismos de persistência e
contas privilegiadas. Matar os processos uma vez não basta: eles **não podem voltar**.

## Tarefa

1. Nada deve escutar nas portas TCP `31337` e `4444`, e os processos responsáveis **não podem reaparecer**
   (nem imediatamente, nem após 1–2 minutos, nem após reboot). Remova todo mecanismo de persistência
   encontrado (unidades systemd, agendamentos etc.) — arquivos de unit devem ser apagados, não só desabilitados.
2. Apague do disco os binários responsáveis pelas duas portas.
3. Existe um **shell com bit SUID de root** escondido no sistema que não pertence a nenhum pacote. Apague-o.
4. Nenhum usuário além de `root` pode ter UID `0`.
5. O usuário `intern` deve continuar existindo, mas **não pode executar nenhum comando como root via `sudo`**.
6. Grave em `/opt/course/10/q3/report.txt` os **caminhos absolutos** dos três binários dos itens 2 e 3
   (um por linha, em qualquer ordem).

Não pare nem desabilite serviços legítimos do sistema (kubelet, containerd, sshd, cron etc.).

## Documentação permitida

- https://kubernetes.io/docs/concepts/security/
- `man ss`, `man lsof`, `man systemctl`, `man crontab`, `man find`, `man dpkg`, `man sudoers`

Quando terminar: `bash verify.sh`
