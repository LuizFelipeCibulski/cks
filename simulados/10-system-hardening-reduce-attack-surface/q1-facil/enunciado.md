# Reduce Attack Surface — Q1 (Fácil)

**Domínio:** System Hardening (10%) — *Minimize host OS footprint (reduce attack surface)*
**Tempo sugerido:** ~4 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

Um scan de portas no `controlplane` encontrou um serviço desconhecido escutando na porta **TCP 6666**. Ele não
faz parte do Kubernetes nem de nenhum componente aprovado.

## Tarefa

1. Descubra qual processo está escutando na porta TCP `6666` e grave o **caminho absoluto do binário** desse
   processo em `/opt/course/10/q1/binary.txt` (apenas o caminho, uma linha).
2. Encerre o processo.
3. Apague o binário do disco.

Ao final, nada deve estar escutando na porta `6666`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/security/
- `man ss`, `man lsof`, `man netstat`, `man ps` (páginas de manual do sistema)

Quando terminar: `bash verify.sh`
