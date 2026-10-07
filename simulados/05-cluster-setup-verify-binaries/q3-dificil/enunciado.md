# Verify Platform Binaries — Q3 (Difícil)

**Domínio:** Cluster Setup (15%) — Verify platform binaries before deploying
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Um alerta de segurança indica que algum binário do Kubernetes **em uso** no node `controlplane`
pode ter sido substituído. Você precisa auditar os binários que estão efetivamente sendo usados,
comparando-os com os binários do **tarball oficial de servidor** do Kubernetes
(`kubernetes-server-linux-<arch>.tar.gz`) da versão correspondente.

## Tarefa

1. Verifique os seguintes binários **em uso** no node `controlplane`:
   - `kube-apiserver`: o binário que roda **dentro do container** do static pod do kube-apiserver;
   - `kubelet`: o binário executado pelo serviço kubelet do host;
   - `kubectl`: o binário que é executado quando você digita `kubectl` no shell do root.
2. Compare cada um com o binário equivalente do tarball oficial de servidor
   (`kubernetes-server-linux-<arch>.tar.gz`) **da mesma versão do respectivo componente**.
3. Grave o resultado em `/opt/course/5/q3/resultado.txt`, exatamente neste formato
   (um por linha, `OK` se confere, `ALTERADO` se não confere):

   ```
   kube-apiserver: OK|ALTERADO
   kubelet: OK|ALTERADO
   kubectl: OK|ALTERADO
   ```

4. Substitua **cada** binário marcado como `ALTERADO` pelo binário oficial do tarball, no mesmo
   caminho em que ele foi encontrado, mantendo-o executável. O cluster deve continuar funcionando
   (node `controlplane` `Ready` e kube-apiserver respondendo).

> Não altere binários que estejam íntegros.

## Documentação permitida

- https://kubernetes.io/releases/download/
- https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG
- https://kubernetes.io/docs/reference/tools/map-crictl-dockercli/

Quando terminar: `bash verify.sh`
