# Behavioral Analytics — Q1 (Fácil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Perform behavioral analytics to detect malicious activities
**Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

No host `controlplane` estão rodando três processos de "agentes" instalados por um fornecedor: `cache-warmer`, `log-shipper` e `metrics-agent`. Os scripts originais não estão mais disponíveis no disco.

Suspeita-se que **um** deles esteja lendo periodicamente o arquivo `/etc/shadow`.

## Tarefa

1. Use `strace` para observar as syscalls dos três processos e descubra qual deles acessa `/etc/shadow`.
2. Grave o **nome** do processo em `/opt/course/22/q1/name.txt` e o seu **PID** em `/opt/course/22/q1/pid.txt`.
3. Grave em `/opt/course/22/q1/syscall.txt` o nome da syscall usada para **abrir** o arquivo `/etc/shadow`.
4. Encerre **somente** o processo malicioso e remova o executável dele do disco. Os outros dois devem continuar rodando.

## Documentação permitida

- https://man7.org/linux/man-pages/man1/strace.1.html
- https://man7.org/linux/man-pages/man5/proc.5.html

Quando terminar: `bash verify.sh`
