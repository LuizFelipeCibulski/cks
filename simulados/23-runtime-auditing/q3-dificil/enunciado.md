# Auditing — Q3 (Difícil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Use Audit Logs to monitor access / Investigate and identify phases of attack
**Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (reinicia o kube-apiserver)
```

## Contexto

O Secret `db-credentials` do namespace `vault` teve seu valor **alterado** sem autorização. O audit logging do cluster está habilitado:

- policy: `/etc/kubernetes/audit/policy.yaml`
- log: `/var/log/kubernetes/audit/audit.log`

A policy atual é muito verbosa: registra tudo em `RequestResponse` — inclusive o **conteúdo** dos Secrets.

## Tarefa

**Investigação** (use somente o audit log):

1. Descubra quem **alterou** o Secret `vault/db-credentials`. Grave o username **exatamente como aparece no audit log** em `/opt/course/23/q3/user.txt`.
2. Grave o `requestReceivedTimestamp` dessa alteração em `/opt/course/23/q3/time.txt`.
3. Grave em `/opt/course/23/q3/readers.txt` os usernames de **todas as ServiceAccounts** que **leram com sucesso** (verbo `get`) o Secret `vault/db-credentials`, um por linha.

**Remediação:**

4. Apague a ServiceAccount responsável pela alteração e o RoleBinding que lhe concedia acesso aos Secrets de `vault`. Não altere permissões de outras ServiceAccounts.

**Redução do audit log:** reescreva `/etc/kubernetes/audit/policy.yaml` para que:

5. Nenhum evento seja gerado no stage `RequestReceived`.
6. Requisições sobre `Secrets` sejam registradas no nível `Metadata` (nunca com o corpo).
7. Requisições `get`, `list` e `watch` sobre qualquer outro recurso **não** sejam registradas.
8. Todo o resto seja registrado no nível `Metadata`.

O kube-apiserver deve estar usando a nova policy, gravando no mesmo arquivo de log e funcionando normalmente.

## Documentação permitida

- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

Quando terminar: `bash verify.sh`
