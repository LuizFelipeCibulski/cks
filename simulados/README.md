# Simulados CKS

Simulados práticos baseados no [currículo oficial da CKS (CNCF, v1.34)](https://github.com/cncf/curriculum),
nos cenários do [Killercoda CKS](https://killercoda.com/cks), no simulador killer.sh e em questões públicas da comunidade.

Cada componente tem **3 questões** (fácil, médio, difícil). Toda questão tem:

| Arquivo        | Para que serve                                              |
|----------------|-------------------------------------------------------------|
| `enunciado.md` | A questão, no estilo da prova                               |
| `setup.sh`     | Prepara o ambiente (namespaces, pods, configs "quebradas"…) |
| `verify.sh`    | Corrige automaticamente e mostra o que falta                |

A solução comentada das 3 questões fica em `solucao.md`, na pasta do componente. Abra só depois de tentar.

## Como usar

1. Abra o playground CKS do Killercoda: https://killercoda.com/playgrounds/scenario/cks
   (cluster kubeadm com `controlplane` + `node01`, containerd, Cilium).
2. Copie este repositório para o controlplane (ex.: `git clone <seu-repo>` ou cole os arquivos).
3. Rode como root, a partir da pasta da questão:
   ```bash
   sudo -i
   cd simulados/01-cluster-setup-network-policies/q1-facil
   bash setup.sh        # prepara o ambiente
   cat enunciado.md     # leia a questão e resolva
   bash verify.sh       # confira
   ```
4. Compare com o `solucao.md` do componente.

Dicas de prova para treinar junto:
- `alias k=kubectl; export do="--dry-run=client -o yaml"; export now="--force --grace-period 0"`
- Ao editar `/etc/kubernetes/manifests/*.yaml`, **faça backup fora dessa pasta** e acompanhe com
  `watch crictl ps` e `journalctl -u kubelet -f` / `/var/log/pods/kube-system_kube-apiserver*`.
- Os setups que mexem no control plane guardam os originais em `/root/cks-backup/`.
  Se o cluster quebrar: `cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/`.

## Componentes

### Cluster Setup (15%)
- `01-cluster-setup-network-policies`
- `02-cluster-setup-cis-benchmark`
- `03-cluster-setup-secure-ingress`
- `04-cluster-setup-node-metadata`
- `05-cluster-setup-verify-binaries`

### Cluster Hardening (15%)
- `06-cluster-hardening-rbac`
- `07-cluster-hardening-serviceaccounts`
- `08-cluster-hardening-restrict-api-access`
- `09-cluster-hardening-upgrade-kubernetes`

### System Hardening (10%)
- `10-system-hardening-reduce-attack-surface`
- `11-system-hardening-apparmor`
- `12-system-hardening-seccomp`

### Minimize Microservice Vulnerabilities (20%)
- `13-microservice-pod-security-standards`
- `14-microservice-security-context`
- `15-microservice-secrets-etcd-encryption`
- `16-microservice-runtime-sandbox-gvisor`
- `17-microservice-pod-to-pod-encryption-cilium`

### Supply Chain Security (20%)
- `18-supply-chain-image-footprint`
- `19-supply-chain-static-analysis`
- `20-supply-chain-vulnerability-scanning-sbom`
- `21-supply-chain-secure-supply-chain`

### Monitoring, Logging and Runtime Security (20%)
- `22-runtime-behavioral-analytics-falco`
- `23-runtime-auditing`
- `24-runtime-immutability`

## Observações

- Os scripts foram escritos para o ambiente do Killercoda (Ubuntu, kubeadm, root). Em outros clusters,
  ajuste nomes de nodes e caminhos.
- Questões que alteram o control plane (apiserver, kubelet, containerd) podem deixar o cluster
  instável se a solução estiver errada. Isso faz parte do treino: o exame cobra saber recuperar.
- Algumas questões precisam de internet para instalar ferramentas (trivy, kube-bench, falco, kubesec,
  kube-linter, gVisor). Os setups instalam automaticamente quando faltar.
- Ao trocar de questão que mexe no control plane, o próprio `setup.sh` restaura o estado original
  antes de montar o novo cenário. O mais seguro, porém, é abrir um playground novo.
