# RBAC — Q2 (Médio)

**Domínio:** Cluster Hardening (15%) — Use Role Based Access Controls to minimize exposure
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Os namespaces `team-a` e `team-b` pertencem a times diferentes. A plataforma quer uma única
definição reutilizável de permissões de leitura de aplicações, concedida **por namespace**.

## Tarefa

1. Crie uma **ClusterRole** chamada `app-viewer` que permita somente `get`, `list` e `watch` em
   `deployments` (grupo `apps`) e `configmaps`.
2. O usuário `jane` deve ter as permissões da ClusterRole `app-viewer` **apenas** no namespace
   `team-a`. Use uma RoleBinding chamada `jane-app-viewer`.
3. A ServiceAccount `ci` do namespace `team-b` deve ter as permissões da ClusterRole `app-viewer`
   **apenas** no namespace `team-b`. Use uma RoleBinding chamada `ci-app-viewer`.
4. Investigue as permissões já existentes da ServiceAccount `legacy` do namespace `team-b` **no
   namespace `team-a`** e grave em `/opt/course/6/q2/legacy.txt` exatamente neste formato
   (`yes` ou `no`):

   ```
   list-pods-team-a: yes|no
   get-secrets-team-a: yes|no
   delete-deployments-team-a: yes|no
   ```

> `jane` não precisa de certificado nesta questão: teste usando impersonation.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/

Quando terminar: `bash verify.sh`
