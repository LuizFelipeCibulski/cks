# Security Context — Q2 (Médio)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~7 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
Uma varredura de compliance pediu que **nenhum Pod privilegiado** rode nos namespaces dos times (todos os namespaces cujo nome começa com `team-`). Considere "Pod privilegiado" todo Pod em que **qualquer** container (inclusive initContainers) tenha `securityContext.privileged: true`.

## Tarefa
1. Encontre todos os Pods privilegiados nos namespaces `team-*` e grave-os em `/opt/course/14/q2/privileged-pods.txt`, um por linha, no formato `<namespace>/<pod>` (estado **antes** de qualquer alteração).
2. Delete os Pods privilegiados que **não** são gerenciados por nenhum controller.
3. Se algum Pod privilegiado pertencer a um Deployment, **não** delete o Deployment: corrija-o para que nenhum container seja privilegiado e garanta que ele continue com todas as réplicas prontas.
4. Pods não privilegiados não devem ser removidos.

## Documentação permitida
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/reference/kubectl/jsonpath/
- https://kubernetes.io/docs/reference/kubectl/quick-reference/

Quando terminar: `bash verify.sh`
