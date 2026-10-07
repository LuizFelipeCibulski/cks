# Auditing — Q2 (Médio)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Use Audit Logs to monitor access
**Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (reinicia o kube-apiserver)
```

## Contexto

O audit logging já está habilitado no kube-apiserver, usando a policy `/etc/kubernetes/audit/policy.yaml` e gravando em `/var/log/kubernetes/audit/audit.log`. A policy atual é provisória e gera log demais.

## Tarefa

Substitua o conteúdo de `/etc/kubernetes/audit/policy.yaml` por uma policy que atenda **todos** os requisitos abaixo:

1. Nenhum evento deve ser gerado no stage `RequestReceived`.
2. **Toda** requisição envolvendo `Secrets`, de qualquer usuário (inclusive dos nodes), deve ser registrada no nível `Metadata`.
3. Requisições `get`, `watch` e `list` feitas por membros do grupo `system:nodes` não devem ser registradas (exceto as de Secrets, vide item 2).
4. Nenhuma requisição sobre o recurso `endpoints` deve ser registrada.
5. Requisições sobre `Deployments` no namespace `prod` devem ser registradas no nível `RequestResponse`.
6. Todo o resto deve ser registrado no nível `Metadata`.

O kube-apiserver deve estar usando a nova policy e funcionando normalmente. Não altere o caminho do log nem o da policy.

## Documentação permitida

- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/

Quando terminar: `bash verify.sh`
