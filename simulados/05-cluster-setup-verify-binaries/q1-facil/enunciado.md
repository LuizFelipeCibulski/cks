# Verify Platform Binaries — Q1 (Fácil)

**Domínio:** Cluster Setup (15%) — Verify platform binaries before deploying
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

A equipe de plataforma baixou alguns binários do Kubernetes para o diretório `/opt/course/5/q1/`
antes de instalá-los em novos nodes. Junto com eles foi salvo o arquivo
`/opt/course/5/q1/sha512sums.txt`, contendo os hashes **SHA512 oficiais** publicados pelo projeto
Kubernetes para esses binários.

Há suspeita de que um dos binários foi adulterado durante a transferência.

## Tarefa

1. Verifique a integridade dos binários `kubectl`, `kubeadm` e `kubelet` em `/opt/course/5/q1/`
   comparando-os com os hashes de `/opt/course/5/q1/sha512sums.txt`.
2. Grave **somente o nome** do binário que não confere (ex: `kubectl`) no arquivo
   `/opt/course/5/q1/adulterado.txt`.
3. Apague o binário adulterado de `/opt/course/5/q1/`. Os binários íntegros e o arquivo
   `sha512sums.txt` devem permanecer.

## Documentação permitida

- https://kubernetes.io/releases/download/#binaries
- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux

Quando terminar: `bash verify.sh`
