# Network Policies — Q2 (Médio)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O serviço de pagamentos precisa ser isolado. Apenas a API de pedidos pode chamar o gateway de pagamentos,
e a API de pedidos não deve conseguir falar com mais nada além do que precisa.

Recursos existentes:

| Namespace  | Pod       | Labels         | Service (porta) |
|------------|-----------|----------------|-----------------|
| `orders`   | `api`     | `app=api`      | `api` (80)      |
| `orders`   | `worker`  | `app=worker`   | —               |
| `payments` | `gateway` | `app=gateway`  | `gateway` (80)  |
| `payments` | `ledger`  | `app=ledger`   | `ledger` (80)   |
| `sandbox`  | `api`     | `app=api`      | —               |

## Tarefa

1. Crie a NetworkPolicy `gateway-ingress` no namespace `payments` que se aplique **somente** aos Pods com label `app=gateway` e
   permita tráfego de entrada **apenas** de Pods com label `app=api` **que estejam no namespace `orders`**, somente na porta TCP `80`.
   - Pods `app=api` de outros namespaces e outros Pods do namespace `orders` **não** podem acessar o gateway.
   - O Pod `ledger` não deve ser afetado por essa política.
2. Crie a NetworkPolicy `api-egress` no namespace `orders` que se aplique **somente** aos Pods com label `app=api` e permita saída **apenas** para:
   - Pods `app=gateway` do namespace `payments` na porta TCP `80`;
   - o DNS do cluster (Pods `k8s-app=kube-dns` no namespace `kube-system`) nas portas `53` UDP e TCP.
   - Todo o resto do egress desses Pods deve ser bloqueado (inclusive para o `ledger`).
3. O Pod `orders/api` deve continuar conseguindo acessar `http://gateway.payments.svc.cluster.local` (por nome).

Não altere labels de Pods/namespaces existentes.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors
- https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/

Quando terminar: `bash verify.sh`
