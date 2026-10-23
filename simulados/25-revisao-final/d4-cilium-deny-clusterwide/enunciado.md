# D4: Cilium deny policies + CiliumClusterwideNetworkPolicy

**Domínio:** Cluster Setup / Microservice Vulnerabilities (Cilium) · **Tempo-alvo:** 9 min

## Preparação

```bash
bash setup.sh   # root, no controlplane
```

## Contexto

| Namespace  | Pod       | Labels                     | Service   |
|------------|-----------|----------------------------|-----------|
| `d4`       | `db`      | `app=db`                   | `db:80`   |
| `d4`       | `app`     | `app=app`                  | —         |
| `d4`       | `debug`   | `app=debug`, `role=debug`  | —         |
| `d4-other` | `echo`    | `app=echo`                 | `echo:80` |
| `d4-other` | `client`  | `app=client`               | —         |
| `d4-other` | `scanner` | `app=scanner`, `role=debug`| —         |

Outro time mantém a CNP `d4/legacy-allow-all`, que libera **todo** ingress para o `db`. Você **não pode
apagar nem editar** essa política.

## Tarefa

1. Crie a CiliumNetworkPolicy `db-deny` no namespace `d4` (selecionando `app=db`) usando **regras de deny**
   para bloquear o ingress no `db` vindo de:
   - Pods `app=debug` do namespace `d4`;
   - **qualquer** Pod do namespace `d4-other`.

   O Pod `app` deve continuar acessando o `db`.
2. Crie a **CiliumClusterwideNetworkPolicy** `debug-deny-world` que se aplique a **todos os Pods com
   `role=debug` de qualquer namespace** e bloqueie, com deny, o egress deles para fora do cluster
   (entidade `world`).
   - Esses Pods devem continuar resolvendo DNS e acessando Services do cluster (ex.: `http://echo.d4-other`).
   - Pods sem `role=debug` não podem ser afetados (ex.: `app` continua acessando a internet).

## Documentação permitida

- https://docs.cilium.io/en/stable/security/policy/language/#deny-policies
- https://docs.cilium.io/en/stable/security/policy/language/#entities-based
- https://docs.cilium.io/en/stable/network/kubernetes/policy/#ciliumclusterwidenetworkpolicy

Quando terminar: `bash verify.sh`
