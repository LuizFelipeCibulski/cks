# D5: apiserver fora do ar + Audit Logging

**Domínio:** Monitoring, Logging and Runtime Security / Cluster Hardening · **Tempo-alvo:** 10 min

## Preparação

```bash
bash setup.sh   # root, no controlplane. ATENÇÃO: este setup DERRUBA o kube-apiserver de propósito
```

## Contexto

Um colega começou a habilitar o audit logging no `kube-apiserver` e saiu de férias. Desde então, o
`kubectl` não responde. O backup do manifest original está em `/root/cks-backup/kube-apiserver.yaml`,
mas **não** vale restaurá-lo: o audit tem que ficar habilitado.

## Tarefa

1. Descubra por que o `kube-apiserver` não sobe e corrija **todos** os problemas.
   Não remova o admission plugin `NodeRestriction`.
2. Crie a policy de audit em `/etc/kubernetes/audit/policy.yaml` com:
   - nenhum evento no estágio `RequestReceived`;
   - `Secrets` (de **qualquer** namespace, inclusive `d5`): nível `Metadata`;
   - qualquer outro recurso do namespace `d5`: nível `RequestResponse`;
   - todo o resto: **não** logar.
3. Os logs devem ir para `/var/log/kubernetes/audit/audit.log` **no host**, mantendo no máximo
   `2` arquivos de backup, por no máximo `5` dias, com `50` MB por arquivo.

## Documentação permitida

- https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/

Quando terminar: `bash verify.sh`
