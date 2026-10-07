# Pod-to-Pod com Cilium — Q1 (Fácil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) — *Implement Pod-to-Pod encryption (Cilium, Istio)* / políticas de rede do Cilium
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

## Contexto

O cluster usa o **Cilium** como CNI. O time `team-blue` quer usar os recursos nativos do Cilium (`CiliumNetworkPolicy`) em vez da `NetworkPolicy` padrão do Kubernetes.

No namespace `team-blue` existem os Pods `frontend` (label `app=frontend`), `backend` (label `app=backend`, nginx na porta 80, exposto pelo Service `backend`) e `other` (label `app=other`).
No namespace `team-green` existe outro Pod chamado `frontend`, também com label `app=frontend`.

## Tarefa

1. Crie uma **CiliumNetworkPolicy** chamada `backend-ingress` no namespace `team-blue` que selecione os Pods com label `app=backend`.
2. A política deve permitir tráfego de entrada (ingress) para o `backend` **somente** a partir de Pods com label `app=frontend` **do namespace `team-blue`**, e **somente** em `TCP/80`.
3. Todo o resto do tráfego de entrada para o `backend` deve ser bloqueado (inclusive do Pod `other` e do `frontend` do namespace `team-green`).

Não use o recurso `NetworkPolicy` (networking.k8s.io) para esta questão.

## Documentação permitida

- https://docs.cilium.io/en/stable/security/policy/language/
- https://docs.cilium.io/en/stable/network/kubernetes/policy/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/

Quando terminar: `bash verify.sh`
