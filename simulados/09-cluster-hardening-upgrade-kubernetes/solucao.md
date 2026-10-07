# Soluções — Upgrade do Kubernetes (kubeadm)

> Por que isso cai na CKS: rodar uma versão sem suporte ou com CVE conhecida é uma das maiores superfícies
> de ataque de um cluster. O Kubernetes mantém apenas as **3 minors mais recentes** com patches de
> segurança; manter o cluster atualizado (patch e minor) é parte do domínio *Cluster Hardening*.

Regras de ouro do upgrade com kubeadm (doc: *Upgrading kubeadm clusters*):

- Ordem: **control plane primeiro**, depois os workers. Sempre `kubeadm` → componentes → `kubelet`/`kubectl`.
- Só se pula **uma minor por vez** (1.34 → 1.35 → 1.36). Patches podem ser pulados.
- O repositório `pkgs.k8s.io` é **por minor** (`.../core:/stable:/v1.35/deb/`). Para ir para outra minor é
  preciso trocar a URL do repo (*Changing the Kubernetes package repository*).
- Version skew: o kubelet pode estar até 3 minors atrás do apiserver, mas **nunca à frente**.
- Os pacotes ficam em `hold` para o `apt upgrade` não atualizá-los sem querer: `unhold` → instala → `hold`.

---

## Q1 (Fácil) — levantar versões e colocar node01 em manutenção

```bash
mkdir -p /opt/course/09/q1

# 1. versão atual do cluster (apiserver)
kubectl version | grep Server          # Server Version: v1.35.1
kubectl version -o json | grep -A2 serverVersion   # alternativa
echo v1.35.1 > /opt/course/09/q1/current-version.txt
# (atalho sem digitar: kubectl version | awk '/Server Version/{print $3}' > /opt/course/09/q1/current-version.txt)

# 2. plano de upgrade
kubeadm upgrade plan | tee /opt/course/09/q1/plan.txt

# 3. versões disponíveis no repositório apt configurado
apt-get update
apt-cache madison kubeadm
#    kubeadm | 1.35.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
#    kubeadm | 1.35.2-1.1 | ...
apt-cache madison kubeadm | awk '{print $3}' | sort -V | tail -1 > /opt/course/09/q1/latest.txt
cat /opt/course/09/q1/latest.txt

# 4. manutenção do node01
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data --force
kubectl get nodes        # node01 Ready,SchedulingDisabled
kubectl get pods -A -o wide --field-selector spec.nodeName=node01
```

Por que cada flag do `drain`:

- `--ignore-daemonsets`: pods de DaemonSet (cilium, kube-proxy) não podem ser removidos — o controller
  os recriaria no mesmo nó. Sem a flag o drain falha.
- `--delete-emptydir-data`: o Deployment `web` usa `emptyDir`; os dados se perdem no despejo, então o kubectl
  exige confirmação explícita.
- `--force`: o pod `debug` não tem controller (pod "solto"); ele será **apagado para sempre**. Sem `--force`
  o drain para com `cannot delete Pods that declare no controller`.

`drain` = `cordon` (marca `spec.unschedulable=true`) + eviction dos pods. Só `cordon` NÃO atende o item 4.

Pegadinhas:

- `kubeadm upgrade plan` mostra a versão alvo do **control plane** (consulta `dl.k8s.io`), já o
  `apt-cache madison` mostra o que **o repositório configurado** tem. Sem trocar o repo, o apt só enxerga a
  minor atual.
- `kubectl version` sem flags mostra Client e Server — não confunda. O que vale para "versão do cluster" é
  o Server (apiserver).

Validação manual: `kubectl get node node01 -o jsonpath='{.spec.unschedulable}'` → `true`.

Para desfazer: `kubectl uncordon node01`.

Docs: https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/

---

## Q2 (Médio) — alinhar node01 com o control plane

```bash
# no controlplane: qual a versão exata dos pacotes?
kubectl get nodes                       # controlplane v1.35.1 / node01 v1.35.0
dpkg -l | grep -E 'kubeadm|kubelet|kubectl'   # ex.: 1.35.1-1.1

# 1. drenar o worker (sempre a partir de onde roda o kubectl/admin.conf)
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data

# 2/3. no worker
ssh node01
apt-mark unhold kubeadm kubelet kubectl
apt-get update
apt-cache madison kubeadm               # confirme que 1.35.1-1.1 existe
apt-get install -y kubeadm=1.35.1-1.1
kubeadm upgrade node                    # atualiza a config local do kubelet (/var/lib/kubelet/config.yaml)
apt-get install -y kubelet=1.35.1-1.1 kubectl=1.35.1-1.1
apt-mark hold kubeadm kubelet kubectl   # 4.
systemctl daemon-reload
systemctl restart kubelet
kubelet --version; kubeadm version -o short; kubectl version --client
exit

# 5. de volta ao controlplane
kubectl uncordon node01
kubectl get nodes                       # ambos v1.35.1, Ready
```

Atalho: os três pacotes de uma vez com
`apt-get install -y --allow-change-held-packages kubeadm=1.35.1-1.1 kubelet=1.35.1-1.1 kubectl=1.35.1-1.1`
— mas lembre-se de rodar `kubeadm upgrade node` **depois do kubeadm novo e antes de reiniciar o kubelet**.

Pegadinhas:

- `kubeadm upgrade node` (worker) ≠ `kubeadm upgrade apply` (primeiro control plane). Nunca rode `apply` no worker.
- Esquecer `systemctl restart kubelet`: o pacote é novo mas o `kubectl get nodes` continua mostrando a
  versão antiga (o processo em execução é o binário antigo).
- Instalar sem especificar `=versão` instala a **mais nova do repo**, que pode ser maior que a do control
  plane — o kubelet não pode ficar à frente do apiserver.
- Erro `Held packages were changed` → faltou `apt-mark unhold` (ou use `--allow-change-held-packages`).
- `kubectl drain`/`uncordon` rodam onde há kubeconfig de admin (normalmente o controlplane), não no node01.

Docs: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/

---

## Q3 (Difícil) — upgrade completo (control plane + worker)

Supondo `cat /opt/course/09/q3/target-version` → `v1.36.0` e cluster em `v1.35.1`
(adapte aos números do seu ambiente; o pacote é `1.36.0-1.1`).

### Repositório

O setup já apontou o repo para a minor correta. Na prova você mesmo faz isso (em **todos** os nós):

```bash
cat /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /
sed -i 's#/v1.35/#/v1.36/#' /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-cache madison kubeadm
```

### Control plane

```bash
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.36.0-1.1
apt-mark hold kubeadm
kubeadm version -o short                 # v1.36.0

kubeadm upgrade plan                     # confere se v1.36.0 aparece como alvo
kubeadm upgrade apply v1.36.0            # confirme com 'y' (ou use -y)
# aguarde: "[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.0"."

kubectl drain controlplane --ignore-daemonsets --delete-emptydir-data
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.36.0-1.1 kubectl=1.36.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon controlplane
kubectl get nodes
```

### Worker

```bash
ssh node01
# (troque o repo para v1.36 aqui também, se necessário, e apt-get update)
apt-mark unhold kubeadm kubelet kubectl
apt-get install -y kubeadm=1.36.0-1.1
kubeadm upgrade node
exit

kubectl drain node01 --ignore-daemonsets --delete-emptydir-data   # no controlplane

ssh node01
apt-get install -y kubelet=1.36.0-1.1 kubectl=1.36.0-1.1
apt-mark hold kubeadm kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
exit

kubectl uncordon node01
kubectl get nodes -o wide
kubectl -n upgrade-q3 get deploy critical-app
```

O que o `kubeadm upgrade apply` faz: checa pré-requisitos e version skew, renova certificados, reescreve
os manifests estáticos em `/etc/kubernetes/manifests` com as imagens novas (apiserver, controller-manager,
scheduler, etcd), atualiza CoreDNS/kube-proxy e a ConfigMap `kubelet-config`. Ele **não** atualiza o
binário do kubelet — por isso o passo do `apt-get install kubelet`.

Pegadinhas:

- `kubeadm upgrade apply` com o kubeadm antigo → erro `Specified version to upgrade to "v1.36.0" is higher
  than the kubeadm version`. Instale o kubeadm novo **antes**.
- Trocar o repo só no controlplane e esquecer o node01: lá o `apt-cache madison` não mostra a versão nova.
- Pular minor (1.34 → 1.36) é recusado pelo kubeadm.
- Drenar o controlplane remove o próprio CoreDNS/workloads dele: lembre-se do `uncordon` ou os pods ficam
  Pending (o `critical-app` precisa estar disponível no final).
- Durante o `apply` o apiserver reinicia; `kubectl` pode dar `connection refused` por ~1 minuto. Espere.
- Se o `apply` falhar no meio, ele faz rollback automático dos manifests (backups em
  `/etc/kubernetes/tmp/kubeadm-backup-manifests-*`).

Validação manual:

```bash
kubectl version
grep image: /etc/kubernetes/manifests/kube-*.yaml
kubectl get nodes
ssh node01 'kubeadm version -o short; apt-mark showhold'
```

Docs:
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/

Dica de velocidade: a página *Upgrading kubeadm clusters* tem todos os comandos em blocos copiáveis —
na prova, abra-a, troque `1.xx.x-*` pela versão pedida e cole.
