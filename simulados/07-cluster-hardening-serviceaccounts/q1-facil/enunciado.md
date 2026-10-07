# ServiceAccounts — Q1 (Fácil)

**Domínio:** Cluster Hardening (15%) — Exercise caution in using service accounts e.g. disable defaults, minimize permissions on newly created ones
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

A aplicação `backend` do namespace `payments` não precisa falar com a API do Kubernetes, portanto
não deve receber nenhum token de ServiceAccount.

## Tarefa

1. Crie no namespace `payments` a ServiceAccount `backend-sa`, configurada para **não** montar
   automaticamente o token da API nos Pods que a usarem.
2. Crie no namespace `payments` o Pod `backend` com a imagem `nginx:1.27-alpine` usando a
   ServiceAccount `backend-sa`.
3. O Pod `backend` deve estar `Running` e **não** pode ter o token montado em
   `/var/run/secrets/kubernetes.io/serviceaccount/`.

## Documentação permitida

- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- https://kubernetes.io/docs/concepts/security/service-accounts/

Quando terminar: `bash verify.sh`
