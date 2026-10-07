# Node Metadata Protection — Q3 (Difícil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O namespace `ml-platform` roda a plataforma de Machine Learning:

- Deployment `cloud-sync`: sincroniza modelos com o bucket da nuvem e **precisa** das credenciais do metadata server (`169.254.169.254`).
- Deployment `trainer` e Pod `notebook`: **não** devem ter acesso ao metadata server.
- Todos os workloads leem modelos do Service `model-store` no namespace `storage` (porta 80).

O time de segurança já criou algumas NetworkPolicies em `ml-platform`, mas a situação atual está ruim: alguns pods não resolvem DNS, ninguém consegue acessar o `model-store` e o metadata server está aberto para todos.

> Neste simulado a "nuvem" é emulada no node `controlplane`: metadata em `http://169.254.169.254/` e uma API externa em `http://198.51.100.10/`.

## Tarefa

1. Nenhum pod do namespace `ml-platform` pode acessar `169.254.169.254`, **exceto** pods com o label `role=metadata-accessor`.
2. O acesso ao metadata deve ser concedido por uma NetworkPolicy **separada** chamada `allow-metadata-accessor` (namespace `ml-platform`), que selecione pods com `role=metadata-accessor` e permita **apenas** egress para `169.254.169.254/32` na porta TCP `80`.
3. Somente os pods do Deployment `cloud-sync` devem ter o label `role=metadata-accessor`. O label deve sobreviver a recriações dos pods. Não remova nenhum workload.
4. Todos os pods de `ml-platform` devem continuar conseguindo:
   - resolver DNS de nomes do cluster (UDP e TCP 53);
   - acessar `http://model-store.storage.svc.cluster.local` (porta 80);
   - acessar IPs externos, como `198.51.100.10`.
5. Restrições:
   - a NetworkPolicy `default-deny-egress` é um requisito de compliance e **não pode ser removida nem alterada**;
   - **não altere** nada no namespace `storage`.

Você pode editar, apagar ou criar as demais NetworkPolicies de `ml-platform` e alterar labels/metadados do namespace `ml-platform` se necessário.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/network-policy-v1/
- https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
- https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

Quando terminar: `bash verify.sh`
