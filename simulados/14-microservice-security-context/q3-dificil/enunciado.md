# Security Context — Q3 (Difícil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~12 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
Os namespaces `fin-a`, `fin-b` e `fin-c` hospedam workloads do time financeiro. A equipe de segurança definiu 4 regras que **nenhum** workload desses namespaces pode violar:

| Regra | Descrição |
|-------|-----------|
| R1 | Nenhum container ou initContainer privilegiado (`privileged: true`) |
| R2 | Não compartilhar o namespace de PID do host (`hostPID`) |
| R3 | Não usar a rede do host (`hostNetwork`) |
| R4 | Nenhum container (em execução) pode rodar com UID efetivo `0` (root) |

## Tarefa
1. Investigue **todos** os workloads (Deployments e Pods avulsos) dos três namespaces e grave em `/opt/course/14/q3/violations.txt` os que violam **pelo menos uma** regra, um por linha, no formato `<namespace>/<nome-do-Deployment-ou-Pod>` (para Pods de um Deployment, use o nome do **Deployment**). Investigue o estado **antes** de corrigir.
2. Corrija **todos** os workloads violadores para que cumpram as 4 regras:
   - Deployments devem ser **editados** (não deletados) e terminar com todas as réplicas prontas;
   - Pods avulsos devem ser recriados com o **mesmo nome**, mesma imagem e mesmo comando, já em conformidade;
   - Para cumprir a R4 use o UID `1000` (quando o workload ainda não define um UID não-root próprio).
3. Workloads que já estavam em conformidade não devem ser alterados de forma a quebrá-los.

## Documentação permitida
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/reference/kubectl/jsonpath/

Quando terminar: `bash verify.sh`
