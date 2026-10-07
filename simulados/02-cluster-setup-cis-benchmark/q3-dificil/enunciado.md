# CIS Benchmark — Q3 (Difícil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Um pentest interno conseguiu listar todos os pods do node `controlplane` fazendo requisições **sem credenciais** diretamente para a API do kubelet. O relatório também cita outros desvios do CIS Kubernetes Benchmark em componentes diferentes. O kube-bench está instalado no controlplane.

## Tarefa

Todas as correções são no node **controlplane**.

1. Antes de corrigir, rode o kube-bench com o target `node` e salve a saída completa em `/opt/course/02/q3/kube-bench-node-before.txt`.
2. **kubelet** — corrija de acordo com o CIS Benchmark:
   - autenticação anônima desabilitada;
   - modo de autorização `Webhook`;
   - porta read-only (`10255`) desabilitada.

   As correções devem estar **efetivas no kubelet em execução**, não apenas em um arquivo.
3. O arquivo de configuração do kubelet (descubra qual é pela linha de comando do processo) e o kubeconfig do kubelet `/etc/kubernetes/kubelet.conf` devem ter permissão `600` ou mais restritiva e pertencer a `root:root`.
4. **etcd** — o etcd deve exigir certificado de cliente válido (achado CIS da seção 2).
5. **kube-controller-manager** — os controllers devem usar credenciais de ServiceAccount individuais (achado CIS da seção 1.3).
6. Rode o kube-bench novamente com o target `node` e salve a saída completa em `/opt/course/02/q3/kube-bench-node-after.txt`.

> O node `controlplane` deve terminar `Ready` e todos os pods do control plane `Running`. A API do kubelet deve continuar acessível para o kube-apiserver (ex.: `kubectl logs` e `kubectl exec` devem funcionar).

## Documentação permitida

- https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md
- https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
- https://etcd.io/docs/latest/op-guide/security/

Quando terminar: `bash verify.sh`
