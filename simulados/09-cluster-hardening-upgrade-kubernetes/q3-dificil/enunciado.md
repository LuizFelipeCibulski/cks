# Upgrade do Kubernetes — Q3 (Difícil)

**Domínio:** Cluster Hardening (15%) — *Upgrade Kubernetes to avoid vulnerabilities*
**Tempo sugerido:** ~12 minutos (o upgrade em si pode levar alguns minutos a mais por causa de downloads)

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

O setup detecta automaticamente a próxima versão disponível no repositório `pkgs.k8s.io` (próxima minor,
se publicada; senão a patch mais nova da minor atual), ajusta o repositório apt dos nós para a minor
correta e grava a **versão alvo** em `/opt/course/09/q3/target-version`. Se não houver nenhuma versão mais
nova disponível, o setup aborta explicando o motivo.

> Atenção: este exercício altera o cluster de forma permanente (não há "rollback" de upgrade).

## Contexto

Uma CVE crítica afeta a versão atual do cluster. A política da empresa exige que todo o cluster rode a
versão indicada em `/opt/course/09/q3/target-version`.

## Tarefa

1. Faça o upgrade do **control plane** (`controlplane`) para a versão alvo usando o kubeadm:
   `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` e demais componentes gerenciados pelo
   kubeadm devem rodar a versão alvo.
2. Atualize `kubelet` e `kubectl` do `controlplane` para a versão alvo. O nó deve ser drenado antes da troca do
   kubelet e voltar a aceitar pods depois.
3. Faça o upgrade do worker `node01` (`kubeadm`, configuração do nó, `kubelet` e `kubectl`) para a versão alvo,
   também drenando e liberando o nó.
4. Os pacotes `kubeadm`, `kubelet` e `kubectl` devem permanecer em **hold** no apt em todos os nós ao final.
5. Ao final, todos os nós devem estar `Ready` e schedulable, e o Deployment `critical-app` no namespace
   `upgrade-q3` deve estar com todas as réplicas disponíveis.

> Se o cluster não tiver `node01`, o item 3 é ignorado pela correção.

## Documentação permitida

- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/
- https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/releases/version-skew-policy/

Quando terminar: `bash verify.sh`
