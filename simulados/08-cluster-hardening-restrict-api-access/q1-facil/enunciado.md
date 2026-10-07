# Restrict API Access — Q1 (Fácil)

**Domínio:** Cluster Hardening (15%) — Restrict access to Kubernetes API
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Um scanner externo conseguiu ler recursos do cluster fazendo requisições **sem credenciais** ao
kube-apiserver. A suspeita é de que alguém criou permissões RBAC para usuários anônimos durante
um debug e esqueceu de remover.

## Tarefa

1. Encontre **todos** os ClusterRoleBindings que concedem permissões ao usuário
   `system:anonymous` ou ao grupo `system:unauthenticated`, **exceto** o binding padrão do
   Kubernetes `system:public-info-viewer`.
2. Grave os nomes desses ClusterRoleBindings em `/opt/course/8/q1/removidos.txt`, um por linha.
3. Remova esses ClusterRoleBindings. O `system:public-info-viewer` deve continuar existindo.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#anonymous-requests
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/#discovery-roles
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/#referring-to-subjects

Quando terminar: `bash verify.sh`
