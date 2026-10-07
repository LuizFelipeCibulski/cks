# Pod-to-Pod com Cilium — Q2 (Médio)

**Domínio:** Minimize Microservice Vulnerabilities (20%) — *Implement Pod-to-Pod encryption (Cilium, Istio)* / políticas L7 e deny do Cilium
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

## Contexto

No namespace `shop` roda a API interna `api` (label `app=api`, Service `api` na porta 80). Ela serve dois caminhos HTTP:

- `/public/` — conteúdo que pode ser consumido pelo cliente;
- `/private/` — conteúdo administrativo que **não** pode ser acessado pela rede.

Também existem os Pods `client` (label `app=client`) e `intruder` (label `app=intruder`).

## Tarefa

1. Crie a **CiliumNetworkPolicy** `api-l7` no namespace `shop`, selecionando `app=api`, de forma que:
   - apenas Pods com `app=client` consigam acessar a `api`, e somente em `TCP/80`;
   - no nível HTTP (L7), apenas requisições **`GET`** para caminhos que começam com **`/public`** sejam permitidas. Qualquer outro método (ex.: `POST`) ou caminho (ex.: `/private/`) deve ser negado;
   - o Pod `intruder` não deve conseguir acessar a `api` de forma alguma.
2. Crie a **CiliumNetworkPolicy** `client-deny-world` no namespace `shop`, selecionando `app=client`, que use uma **regra de deny de egress** (`egressDeny`) para impedir o `client` de falar com qualquer destino **fora do cluster** (entidade `world`).
   - O `client` deve continuar conseguindo resolver DNS e acessar a `api` (`http://api/public/`).

## Documentação permitida

- https://docs.cilium.io/en/stable/security/policy/language/
- https://docs.cilium.io/en/stable/security/http/
- https://docs.cilium.io/en/stable/security/policy/language/#deny-policies

Quando terminar: `bash verify.sh`
