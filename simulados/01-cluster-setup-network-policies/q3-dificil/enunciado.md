# Network Policies — Q3 (Difícil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Uma aplicação de três camadas roda em namespaces separados. Outro administrador começou a implementar o
isolamento de rede, mas deixou o trabalho pela metade e a aplicação está com comportamento inconsistente.
Você deve terminar a microsegmentação. **Revise as NetworkPolicies já existentes** nesses namespaces: o resultado
final (a soma de todas as políticas) precisa atender exatamente aos requisitos abaixo.

| Namespace  | Deployment | Labels dos Pods | Service : porta |
|------------|------------|-----------------|-----------------|
| `frontend` | `web`      | `app=web`       | `web:80`        |
| `frontend` | `debug`    | `app=debug`     | —               |
| `backend`  | `api`      | `app=api`       | `api:8080`      |
| `backend`  | `batch`    | `app=batch`     | —               |
| `database` | `db`       | `app=db`        | `db:5432`       |

## Tarefa

1. Nos namespaces `frontend`, `backend` e `database` deve existir uma NetworkPolicy chamada `default-deny` que bloqueie
   **todo** Ingress e Egress de **todos** os Pods do namespace.
2. **Todos** os Pods desses três namespaces devem conseguir resolver nomes DNS (Pods `k8s-app=kube-dns` do namespace `kube-system`, porta 53 UDP e TCP).
3. `frontend`:
   - Pods `app=web` aceitam conexões na porta TCP `80` vindas de **qualquer** origem.
   - Pods `app=web` podem iniciar conexões apenas para os Pods `app=api` do namespace `backend` na porta TCP `8080` (além do DNS).
4. `backend`:
   - Pods `app=api` aceitam conexões na porta TCP `8080` **somente** de Pods `app=web` do namespace `frontend`.
   - Pods `app=api` podem iniciar conexões apenas para:
     - Pods `app=db` do namespace `database` na porta TCP `5432`;
     - a API externa de um parceiro no IP `1.1.1.1` (use um `ipBlock` com CIDR `/32`), porta TCP `443`;
     - DNS.
5. `database`:
   - Pods `app=db` aceitam conexões na porta TCP `5432` **somente** de Pods `app=api` do namespace `backend`.
6. Qualquer outro fluxo deve ser bloqueado (por exemplo: `web` → `db`, `batch` → `db`, `debug` → `api`, Pods de outros namespaces → `api`/`db`).
7. Não altere Deployments, Services nem labels de namespaces; você pode criar, editar e apagar NetworkPolicies.

Ao final, a partir do Pod `web` o comando abaixo deve funcionar:

```bash
kubectl -n frontend exec deploy/web -- wget -qO- -T3 http://api.backend.svc.cluster.local:8080
```

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

Quando terminar: `bash verify.sh`
