# ServiceAccounts — Q2 (Médio)

**Domínio:** Cluster Hardening (15%) — Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

No namespace `orders` o Deployment `orders-web` está usando a ServiceAccount `default` e recebe
um token da API que ele não usa. Além disso, o pipeline de CI precisa de um token de curta
duração da ServiceAccount `orders-ci` (já existente) para um deploy pontual.

## Tarefa

1. Crie a ServiceAccount `orders-web-sa` no namespace `orders` e faça o Deployment `orders-web`
   usá-la.
2. Os Pods do Deployment `orders-web` **não** podem ter o token da API montado.
3. A ServiceAccount `default` do namespace `orders` não deve montar tokens automaticamente
   em nenhum Pod que venha a usá-la.
4. Gere um token para a ServiceAccount `orders-ci` com validade de **1 hora** e salve **somente o
   token** (o JWT) em `/opt/course/7/q2/orders-ci.token`. Não crie Secrets do tipo
   `kubernetes.io/service-account-token` para isso.

O Deployment `orders-web` deve continuar com todas as réplicas disponíveis.

## Documentação permitida

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/

Quando terminar: `bash verify.sh`
