# ServiceAccounts — Q3 (Difícil)

**Domínio:** Cluster Hardening (15%) — Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

No namespace `observer`, um colega tentou criar o Pod `pod-lister`, que precisa listar os Pods do
próprio namespace chamando a API do Kubernetes diretamente (via `curl`). O manifesto que ele usou
está em `/opt/course/7/q3/pod-lister.yaml`, mas a chamada à API não funciona. Além disso, os
demais workloads do namespace (`web` e `cache`) recebem tokens e permissões que não deveriam ter.

## Tarefa

1. Crie a ServiceAccount `pod-lister-sa` no namespace `observer` com montagem automática de token
   **desabilitada**.
2. Conceda a `pod-lister-sa` somente `get` e `list` em `pods` no namespace `observer`
   (Role `pod-list` e RoleBinding `pod-lister-sa-pod-list`).
3. Corrija o Pod `pod-lister` (mantenha nome, namespace e imagem) para que:
   - use a ServiceAccount `pod-lister-sa`;
   - **não** tenha o volume de token padrão (`kube-api-access-*`);
   - receba um token **projetado** em `/var/run/secrets/tokens/token`, com validade de
     **3600** segundos e com a **audience aceita pelo kube-apiserver deste cluster**
     (descubra qual é);
   - tenha o certificado da CA do cluster disponível em `/var/run/secrets/tokens/ca.crt`;
   - consiga executar com sucesso, de dentro do container:
     ```
     curl --cacert /var/run/secrets/tokens/ca.crt \
       -H "Authorization: Bearer $(cat /var/run/secrets/tokens/token)" \
       https://kubernetes.default.svc/api/v1/namespaces/observer/pods
     ```
4. Nenhum outro Pod do namespace `observer` pode ter token de ServiceAccount montado, e a
   ServiceAccount `default` de `observer` não deve ter nenhuma permissão via RBAC.
   Os Deployments `web` e `cache` devem continuar disponíveis.

## Documentação permitida

- https://kubernetes.io/docs/concepts/storage/projected-volumes/#serviceaccounttoken
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#launch-a-pod-using-service-account-token-projection
- https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

Quando terminar: `bash verify.sh`
