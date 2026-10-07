# Pod-to-Pod com Cilium — Q3 (Difícil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) — *Implement Pod-to-Pod encryption (Cilium, Istio)*
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane (pode levar ~2 min: reinicia os agentes do Cilium)
```

## Contexto

A auditoria de compliance exige que **todo o tráfego entre Pods que atravessa nós seja criptografado** e que a API de pagamentos só seja acessível pelo seu cliente legítimo.
O cluster usa Cilium como CNI. A criptografia transparente **ainda não está habilitada**.

No namespace `secure-payments` existem:
- o Deployment `payment-api` (label `app=payment-api`, porta `8080`, Service `payment-api`);
- o Pod `payment-client` (label `app=payment-client`);
- o Pod `attacker` (label `app=attacker`).

O time de rede já criou algumas políticas nesse namespace no passado.

## Tarefa

1. Habilite a **criptografia transparente com WireGuard** no Cilium do cluster. A mudança deve estar persistida na configuração do Cilium (ConfigMap `kube-system/cilium-config`) e **efetivamente ativa** em todos os agentes do Cilium.
2. Grave a saída do comando de status de criptografia executado **dentro do agente Cilium que roda no node `controlplane`** em `/opt/course/17/encrypt-status.txt`.
3. Garanta que, no namespace `secure-payments`, **somente** Pods com `app=payment-client` consigam acessar `app=payment-api` em `TCP/8080`. Crie para isso a CiliumNetworkPolicy `payment-api-ingress`. O Pod `attacker` não pode conseguir acessar a API.
4. O time quer migrar no futuro para **mutual authentication** do Cilium (o SPIRE ainda **não** está instalado no cluster). Prepare o manifesto de uma CiliumNetworkPolicy chamada `payment-api-mutual-auth` (namespace `secure-payments`), equivalente à regra do item 3, mas exigindo autenticação mútua na regra de ingress. Salve-o em `/opt/course/17/mutual-auth.yaml`.
   - O manifesto deve ser válido para o API server (`--dry-run=server`), mas **NÃO** deve ser aplicado no cluster (sem SPIRE, o tráfego seria descartado).

## Documentação permitida

- https://docs.cilium.io/en/stable/security/network/encryption-wireguard/
- https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/
- https://docs.cilium.io/en/stable/security/policy/language/
- https://docs.cilium.io/en/stable/cmdref/cilium-dbg_encrypt_status/

Quando terminar: `bash verify.sh`
