# Node Metadata Protection — Q1 (Fácil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O cluster roda em um provedor de nuvem que expõe o **metadata server** da instância em `169.254.169.254`. Qualquer pod que consiga falar com esse endereço pode obter, por exemplo, as credenciais IAM do node.

> Neste simulado a "nuvem" é emulada no node `controlplane`: o metadata server responde em `http://169.254.169.254/` e existe uma API externa qualquer em `http://198.51.100.10/`. Os pods do exercício rodam no `controlplane`.

No namespace `cloud-app` existem os pods `web` e `worker`. Hoje ambos conseguem ler `http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role`.

## Tarefa

Crie uma NetworkPolicy chamada `deny-metadata` no namespace `cloud-app` que:

1. Se aplique a **todos** os pods do namespace `cloud-app`.
2. Impeça o tráfego de saída (egress) desses pods para o IP `169.254.169.254`.
3. Mantenha liberado o egress para **qualquer outro IP externo** (por exemplo `198.51.100.10`).
4. Não restrinja o tráfego de entrada (ingress) dos pods.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
- https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/

Quando terminar: `bash verify.sh`
