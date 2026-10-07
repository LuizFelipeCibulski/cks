# Immutability — Q1 (Fácil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Ensure immutability of containers at runtime
**Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

No namespace `immutable` existe o Deployment `logger`, cujo container (`logger`) grava periodicamente em `/app/logs/app.log`. Hoje o container pode escrever em qualquer lugar do seu filesystem — um atacante que ganhe acesso a ele poderia baixar ferramentas ou alterar binários.

## Tarefa

1. Torne o filesystem raiz do container `logger` **somente leitura**.
2. O diretório `/app/logs` deve continuar gravável, usando um volume `emptyDir` chamado `logs`. Nenhum outro caminho deve ser gravável.
3. O Deployment deve continuar funcionando: Pod `Running` e o arquivo `/app/logs/app.log` sendo atualizado.

## Documentação permitida

- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir

Quando terminar: `bash verify.sh`
