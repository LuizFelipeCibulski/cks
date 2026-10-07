# Secrets — Q2 (Médio)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~7 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
Durante uma investigação de incidente você precisa coletar evidências sobre credenciais usadas em dois namespaces: `legacy` e `monitoring`.

## Tarefa
1. Um dos Secrets do namespace `legacy` contém a chave `admin-password`. Grave o valor **decodificado** dessa chave em `/opt/course/15/q2/admin-password.txt`.
2. O Pod `agent` no namespace `monitoring` roda com uma ServiceAccount. Grave o **token da ServiceAccount, exatamente como visto de dentro do container** do Pod `agent`, em `/opt/course/15/q2/sa-token.txt`.
3. O container do Pod `agent` recebe a variável de ambiente `DB_PASS` a partir de um Secret. Grave em `/opt/course/15/q2/db-pass.txt` uma única linha no formato `<nome-do-secret>:<valor-decodificado>`.

## Documentação permitida
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/concepts/security/service-accounts/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/

Quando terminar: `bash verify.sh`
