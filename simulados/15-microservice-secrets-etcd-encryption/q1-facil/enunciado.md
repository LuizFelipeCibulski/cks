# Secrets — Q1 (Fácil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~4 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
A aplicação do namespace `vault-app` precisa de credenciais de banco de dados que hoje estão hard-coded na imagem.

## Tarefa
1. Crie no namespace `vault-app` um Secret genérico chamado `db-credentials` com as chaves:
   - `username` = `appuser`
   - `password` = `Sup3r-S3cr3t!`
2. Crie o Pod `app` no namespace `vault-app` (imagem `busybox:1.36`, comando `sleep 1d`) que:
   - exponha a chave `username` como variável de ambiente `DB_USER`;
   - monte o Secret **inteiro** como volume **somente leitura** em `/etc/db-credentials`.
3. O Pod deve estar `Running`.

## Documentação permitida
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/

Quando terminar: `bash verify.sh`
