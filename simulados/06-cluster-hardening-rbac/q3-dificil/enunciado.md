# RBAC — Q3 (Difícil)

**Domínio:** Cluster Hardening (15%) — Use Role Based Access Controls to minimize exposure
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

A desenvolvedora **dev-maria** (time `developers`) vai trabalhar no namespace `project-x`.
Ela deve acessar o cluster com um certificado de cliente assinado pela CA do cluster, e deve ter
**somente** as permissões necessárias. Uma auditoria recente também apontou que o namespace
`project-x` tem permissões herdadas de configurações antigas que precisam ser revistas.

## Tarefa

1. Gere uma chave privada RSA 2048 em `/opt/course/6/q3/dev-maria.key` e um CSR em
   `/opt/course/6/q3/dev-maria.csr` com **CN=`dev-maria`** e **O=`developers`**.
2. Crie um objeto `CertificateSigningRequest` chamado `dev-maria` usando o signer
   `kubernetes.io/kube-apiserver-client`, com uso `client auth` e validade de 1 dia
   (`86400` segundos). Aprove-o e salve o certificado emitido em `/opt/course/6/q3/dev-maria.crt`.
3. Crie o kubeconfig `/opt/course/6/q3/dev-maria.kubeconfig` contendo o cluster atual, o usuário
   `dev-maria` (com o certificado e a chave acima) e um contexto chamado `dev-maria`, que deve ser
   o `current-context`.
4. Usando o kubeconfig acima, `dev-maria` deve conseguir **somente** no namespace `project-x`:
   `get`, `list`, `watch`, `create` e `delete` em `pods`, e `get` em `pods/log`.
   Crie para isso uma Role `pod-developer` e uma RoleBinding `dev-maria-pod-developer`.
5. As permissões **efetivas** de `dev-maria` (incluindo as obtidas por grupos) não podem ir além
   do item 4: ela não pode, por exemplo, criar deployments, ler secrets, usar `pods/exec`,
   acessar outros namespaces ou ler nodes. Encontre e remova/ajuste o que estiver concedendo
   permissões a mais — sem apagar ClusterRoles padrão do sistema.
6. A ServiceAccount `ci-runner` do namespace `project-x` não deve ter **nenhuma** permissão
   cluster-wide; ela deve continuar apenas com o acesso de leitura (`view`) que já possui em
   `project-x`.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#normal-user
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certificates
- https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/

Quando terminar: `bash verify.sh`
