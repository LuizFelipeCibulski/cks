# D3: CiliumNetworkPolicy com egress por FQDN

**Domínio:** Cluster Setup / Microservice Vulnerabilities (Cilium) · **Tempo-alvo:** 7 min

## Preparação

```bash
bash setup.sh   # root, no controlplane (precisa de internet para o teste)
```

## Contexto

No namespace `d3` existem o Pod `crawler` (label `app=crawler`, imagem com `curl`) e o Pod `cache`
(label `app=cache`, nginx na porta 80, exposto pelo Service `cache`).

O `crawler` só pode buscar dados no site oficial do Kubernetes. Como os IPs do site mudam, a regra precisa
ser **por nome DNS**, e não por CIDR.

## Tarefa

Crie a **CiliumNetworkPolicy** `crawler-egress` no namespace `d3`, selecionando `app=crawler`, para que o
egress do `crawler` permita **somente**:

1. DNS para o kube-dns (`k8s-app=kube-dns` no `kube-system`), porta 53, com o proxy DNS do Cilium
   **inspecionando** as consultas (necessário para regras por FQDN);
2. HTTPS (`TCP/443`) para o FQDN **exato** `kubernetes.io`;
3. `TCP/80` para os Pods `app=cache` do próprio namespace.

Todo o resto deve ser bloqueado (ex.: `https://example.com`, `http://kubernetes.io` na porta 80).
Não use `NetworkPolicy` (networking.k8s.io).

## Documentação permitida

- https://docs.cilium.io/en/stable/security/policy/language/#dns-based
- https://docs.cilium.io/en/stable/security/dns/

Quando terminar: `bash verify.sh`
