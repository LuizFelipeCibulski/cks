# D6: Pod Security Admission restricted + hardening do Deployment

**Domínio:** Minimize Microservice Vulnerabilities / Cluster Hardening · **Tempo-alvo:** 8 min

## Preparação

```bash
bash setup.sh
```

## Contexto

No namespace `d6` rodam o Deployment `web` (`nginxinc/nginx-unprivileged`, porta 8080, Service `web`) e o
Pod avulso `legacy-root`.

## Tarefa

1. Faça o namespace `d6` **impor** (`enforce`) o Pod Security Standard `restricted`.
2. Pods já existentes que violam o padrão devem ser removidos. Depois disso, **apenas** os Pods do `web` devem existir no namespace.
3. Ajuste o Deployment `web` para que ele volte a ter **2/2** réplicas prontas, compatíveis com `restricted`, e que:
   - o filesystem raiz do container seja **somente leitura** (use um `emptyDir` em `/tmp`, onde o nginx escreve);
   - use a nova ServiceAccount `web-sa`, que **não** monta o token da API automaticamente.
4. O nginx deve continuar respondendo em `localhost:8080` dentro do Pod.

## Documentação permitida

- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/

Quando terminar: `bash verify.sh`
