# Upgrade do Kubernetes — Q2 (Médio)

**Domínio:** Cluster Hardening (15%) — *Upgrade Kubernetes to avoid vulnerabilities*
**Tempo sugerido:** ~7 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

> Requer o nó `node01`. Se o ambiente não permitir montar o cenário (sem node01 ou sem versão anterior
> disponível no repositório), o setup aborta com uma mensagem explicando o motivo.

## Contexto

O control plane já foi atualizado para a última patch corrigindo uma CVE, mas o worker `node01` ficou para
trás: `kubeadm`, `kubelet` e `kubectl` dele estão em uma patch mais antiga. Use `kubectl get nodes` para ver a
diferença.

## Tarefa

1. Antes de mexer no `node01`, retire os workloads dele de forma segura (pods de DaemonSet podem permanecer).
2. Atualize o `kubeadm` do `node01` para **exatamente a mesma versão de pacote** instalada no `controlplane`
   e aplique a atualização de configuração do nó com o kubeadm.
3. Atualize `kubelet` e `kubectl` do `node01` para a mesma versão e garanta que o kubelet esteja rodando a
   versão nova.
4. Os pacotes `kubeadm`, `kubelet` e `kubectl` do `node01` devem continuar **travados** (hold) no apt
   ao final.
5. Ao final, `node01` deve estar `Ready` e aceitando pods novamente.

Não altere a versão do `controlplane`.

## Documentação permitida

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/

Quando terminar: `bash verify.sh`
