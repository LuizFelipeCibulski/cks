# Revisão final (véspera da prova)

Sete drills rápidos com cenários **diferentes** dos componentes 17 e 22, focados no que mais cai.
Mesma dinâmica dos outros simulados: `bash setup.sh` → `enunciado.md` → `bash verify.sh` → `../solucao.md`.

| Drill | Tema | Tempo-alvo |
|-------|------|-----------:|
| `d1-falco-override-output`     | Falco: override de regra padrão + `file_output`               | 6 min |
| `d2-falco-regra-custom`        | Falco: regra nova, container.id → Pod → Deployment, conter     | 8 min |
| `d3-cilium-fqdn`               | CiliumNetworkPolicy com `toFQDNs` + proxy DNS                  | 7 min |
| `d4-cilium-deny-clusterwide`   | `ingressDeny`/`egressDeny`, entities, CCNP                     | 9 min |
| `d5-audit-apiserver-quebrado`  | apiserver fora do ar (`crictl logs`) + audit policy/volumes    | 10 min |
| `d6-psa-hardening`             | PSA restricted, securityContext, RO rootfs, SA sem token       | 8 min |
| `d7-encryption-at-rest`        | EncryptionConfiguration + etcdctl                              | 9 min |

**Total ≈ 57 min.** Se passar 1,5× do tempo-alvo, pare, leia a solução e refaça do zero.

## Como rodar

```bash
sudo -i
cd simulados/25-revisao-final/d1-falco-override-output
bash setup.sh && cat enunciado.md
# ... resolve ...
bash verify.sh
```

- D5 e D7 mexem no `kube-apiserver`. Os setups deles restauram o manifest original antes de começar.
- D3 e D4 precisam de internet saindo do cluster (killercoda tem).
- Para limpar tudo: `bash reset.sh`.
