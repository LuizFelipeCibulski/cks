# Pod Security Standards — Q2 (Médio)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~7 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
Existem dois namespaces de aplicação: `apps-prod` e `apps-dev`. Nenhum deles tem Pod Security Admission configurado e vários Pods já estão rodando em `apps-prod`. A política da empresa passa a exigir:

| Namespace   | enforce                        | warn                    | audit                   |
|-------------|--------------------------------|-------------------------|-------------------------|
| `apps-prod` | `restricted`, versão **`v1.34`** | `restricted`, `latest` | `restricted`, `latest` |
| `apps-dev`  | `baseline`, `latest`           | `restricted`, `latest` | —                       |

## Tarefa
1. Aplique a política acima aos dois namespaces, usando as labels do Pod Security Admission (incluindo as labels de versão).
2. Descubra quais Pods **já existentes** em `apps-prod` violam o nível `restricted`. Grave **somente os nomes** desses Pods em `/opt/course/13/q2/violations.txt`, um por linha.
3. Delete de `apps-prod` os Pods que violam `restricted` (não os recrie). Os Pods compatíveis devem continuar rodando.

## Documentação permitida
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

Quando terminar: `bash verify.sh`
