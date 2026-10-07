# Upgrade do Kubernetes — Q1 (Fácil)

**Domínio:** Cluster Hardening (15%) — *Upgrade Kubernetes to avoid vulnerabilities*
**Tempo sugerido:** ~4 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

A equipe de segurança recebeu um alerta de CVE e quer planejar o upgrade do cluster. Antes de qualquer
mudança, é preciso levantar as versões disponíveis e tirar o worker de circulação para manutenção.

## Tarefa

1. Grave em `/opt/course/09/q1/current-version.txt` a versão **atual do cluster** (versão do kube-apiserver),
   no formato `vX.Y.Z` (ex.: `v1.35.1`).
2. Grave em `/opt/course/09/q1/plan.txt` a saída completa do comando do kubeadm que mostra o
   **plano de upgrade** do control plane.
3. Grave em `/opt/course/09/q1/latest.txt` **apenas** a versão mais nova do pacote `kubeadm` disponível no
   repositório apt atualmente configurado no `controlplane`, no formato exibido pelo apt (ex.: `1.35.3-1.1`).
4. Coloque o nó `node01` em manutenção: ele não deve aceitar novos pods e não deve sobrar nenhum pod de
   workload nele (pods de DaemonSet podem permanecer). Não remova o nó do cluster.

> Se o cluster não tiver `node01`, o item 4 é ignorado pela correção.

## Documentação permitida

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/

Quando terminar: `bash verify.sh`
