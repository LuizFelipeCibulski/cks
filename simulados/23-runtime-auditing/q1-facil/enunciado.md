# Auditing — Q1 (Fácil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Use Audit Logs to monitor access
**Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (pode reiniciar o kube-apiserver)
```

## Contexto

O time de compliance escreveu uma audit policy e a deixou em `/etc/kubernetes/audit/policy.yaml`. O audit logging ainda **não** está habilitado no cluster.

## Tarefa

Configure o kube-apiserver para:

1. Usar a policy `/etc/kubernetes/audit/policy.yaml` (não altere a policy).
2. Gravar o audit log (backend de log) em `/var/log/kubernetes/audit/audit.log`. No **host**, os logs também devem aparecer em `/var/log/kubernetes/audit/audit.log`.
3. Manter no máximo `7` dias de logs antigos.
4. Manter no máximo `2` arquivos de log rotacionados.
5. Rotacionar o arquivo ao atingir `50` MB.

O apiserver deve voltar a funcionar normalmente.

## Documentação permitida

- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

Quando terminar: `bash verify.sh`
