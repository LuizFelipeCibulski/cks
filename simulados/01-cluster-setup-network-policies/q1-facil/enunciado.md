# Network Policies — Q1 (Fácil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O namespace `restricted` hospeda aplicações que ainda não passaram por revisão de segurança.
Hoje qualquer Pod do cluster consegue falar com elas, e elas conseguem falar com qualquer coisa.
O time de segurança quer adotar o modelo "deny by default" nesse namespace.

Existem dois Pods no namespace `restricted` (`app1` e `app2`) e um Pod de teste `probe` no namespace `cks-probe`.

## Tarefa

1. Crie uma NetworkPolicy chamada `default-deny` no namespace `restricted` que:
   - selecione **todos** os Pods do namespace;
   - bloqueie **todo** o tráfego de entrada (Ingress) **e** de saída (Egress) desses Pods.
2. Salve o manifesto que você aplicou em `/opt/course/netpol/q1/default-deny.yaml`.

Não altere os Pods existentes nem o namespace `cks-probe`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/network-policies/
- https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-policies

Quando terminar: `bash verify.sh`
