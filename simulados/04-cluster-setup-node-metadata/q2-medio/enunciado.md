# Node Metadata Protection — Q2 (Médio)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O metadata server da nuvem responde em `169.254.169.254`. A aplicação de pagamentos, no namespace `payments`, é composta pelos Deployments `shop-frontend`, `shop-backend` e `api` (com um Service `api` na porta 80).

O `shop-frontend` é exposto à internet e uma auditoria apontou que, se ele for comprometido (ex.: SSRF), o atacante consegue ler as credenciais IAM do node pelo metadata server. O `shop-backend`, por outro lado, **precisa** continuar lendo o metadata server.

> Neste simulado a "nuvem" é emulada no node `controlplane`: metadata em `http://169.254.169.254/` e uma API externa em `http://198.51.100.10/`.

## Tarefa

Crie uma NetworkPolicy chamada `frontend-deny-metadata` no namespace `payments` que:

1. Se aplique **somente** aos pods do Deployment `shop-frontend` (descubra os labels adequados).
2. Bloqueie todo egress desses pods para `169.254.169.254`.
3. Mantenha, para esses pods:
   - resolução DNS de nomes do cluster (UDP e TCP 53);
   - acesso ao Service `api` (namespace `payments`, porta TCP 80), usando o nome `api.payments.svc.cluster.local`;
   - acesso a qualquer outro IP externo (ex.: `198.51.100.10`).
4. Não afete os pods de `shop-backend` e `api` e não restrinja ingress.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

Quando terminar: `bash verify.sh`
