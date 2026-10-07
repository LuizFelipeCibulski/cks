# RBAC — Q1 (Fácil)

**Domínio:** Cluster Hardening (15%) — Use Role Based Access Controls to minimize exposure
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

No namespace `finance` existe a ServiceAccount `report-bot`, usada por um job de relatórios
que só precisa **ler** Pods desse namespace. Hoje ela não tem nenhuma permissão.

## Tarefa

1. Crie no namespace `finance` uma **Role** chamada `pod-reader` que permita apenas os verbos
   `get`, `list` e `watch` no recurso `pods`.
2. Crie no namespace `finance` uma **RoleBinding** chamada `report-bot-pod-reader` que associe a
   Role `pod-reader` à ServiceAccount `report-bot`.
3. A ServiceAccount `report-bot` **não** deve conseguir criar/deletar Pods, ler Secrets, nem
   listar Pods em outros namespaces.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/

Quando terminar: `bash verify.sh`
