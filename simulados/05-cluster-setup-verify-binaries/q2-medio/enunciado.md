# Verify Platform Binaries — Q2 (Médio)

**Domínio:** Cluster Setup (15%) — Verify platform binaries before deploying
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Em `/opt/course/5/q2/` existem os binários `kubectl`, `kubeadm`, `kubelet` e `kube-proxy`.
Eles deveriam ser exatamente os binários **oficiais** `linux` da **mesma versão do Kubernetes que
está rodando nos nodes deste cluster**, mas desta vez ninguém salvou os hashes.

## Tarefa

1. Descubra a versão do Kubernetes dos nodes do cluster e grave-a (formato `vX.Y.Z`) em
   `/opt/course/5/q2/versao.txt`.
2. Obtenha os checksums **oficiais SHA256** desses binários para essa versão, publicados em
   `dl.k8s.io`, e verifique cada um dos quatro binários.
3. Grave em `/opt/course/5/q2/adulterados.txt` o nome de **todos** os binários que não conferem,
   um por linha.
4. Mova os binários que não conferem para o diretório `/opt/course/5/q2/quarentena/`
   (crie-o se necessário). Os binários íntegros devem continuar em `/opt/course/5/q2/`.

## Documentação permitida

- https://kubernetes.io/releases/download/#binaries
- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG

Quando terminar: `bash verify.sh`
