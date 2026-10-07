# CIS Benchmark — Soluções

> Conceito geral: o **CIS Kubernetes Benchmark** é um conjunto de recomendações de hardening para o control plane (seção 1), etcd (seção 2), políticas do control plane (seção 3), worker nodes/kubelet (seção 4) e policies (seção 5). O **kube-bench** (Aqua Security) automatiza essas checagens: para cada item ele mostra `[PASS]`, `[FAIL]`, `[WARN]` (checagens manuais) ou `[INFO]`, e ao final uma seção **Remediations** dizendo exatamente o que editar. Na prova, a forma mais rápida é: rodar kube-bench → copiar a remediação → aplicar → rodar de novo só aquele check.
>
> Os números dos checks (1.2.15, 1.3.2...) mudam conforme a versão do benchmark (cis-1.9, cis-1.10...). Use `--check` com o ID que **a sua** saída mostrar.

Comandos úteis do kube-bench:

```bash
kube-bench run --targets master            # control plane (apiserver, controller-manager, scheduler, arquivos)
kube-bench run --targets node              # kubelet
kube-bench run --targets etcd              # etcd
kube-bench run --targets master --check 1.3.2   # um check específico
kube-bench run --targets master | grep -A3 profiling
```

---

## Q1 (Fácil) — profiling no controller-manager e scheduler

### Passo a passo

```bash
mkdir -p /opt/course/02/q1
kube-bench run --targets master > /opt/course/02/q1/kube-bench-before.txt
grep -E '^\[FAIL\].*profiling' /opt/course/02/q1/kube-bench-before.txt
# [FAIL] 1.2.x Ensure that the --profiling argument is set to false   (apiserver — não mexer nesta questão)
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false   (controller-manager)
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false   (scheduler)
```

Edite os manifests estáticos (o kubelet recria o pod sozinho ao salvar):

```bash
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-controller-manager
    - --profiling=false          # era --profiling=true
    - --allocate-node-cidrs=true
    ...
```

```bash
vim /etc/kubernetes/manifests/kube-scheduler.yaml
```

```yaml
  - command:
    - kube-scheduler
    - --profiling=false          # era --profiling=true
    - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
    ...
```

Ou, mais rápido:

```bash
sed -i 's/--profiling=true/--profiling=false/' /etc/kubernetes/manifests/kube-{controller-manager,scheduler}.yaml
```

Aguarde os pods voltarem e gere o "depois":

```bash
watch crictl ps                       # ou: kubectl -n kube-system get pod -w
ps aux | grep -E 'kube-(controller|scheduler)' | grep -o -- '--profiling=[a-z]*'
kube-bench run --targets master > /opt/course/02/q1/kube-bench-after.txt
grep profiling /opt/course/02/q1/kube-bench-after.txt
```

### Por quê
`--profiling=true` (padrão!) expõe `/debug/pprof`, que permite coletar perfis de CPU/memória e dumps de goroutines — informação útil a um atacante e vetor de DoS. Em produção não há motivo para deixá-lo ligado.

### Pegadinhas
- O padrão do `--profiling` é **true**: se a flag não existir, o check falha. É preciso **adicionar** `--profiling=false` quando ela não está presente.
- Ficou flag duplicada? O último valor vence — mas evite duplicar, isso confunde o kube-bench.
- Nunca deixe cópias `.yaml` dentro de `/etc/kubernetes/manifests/` (o kubelet sobe tudo que está lá). Faça backup em outro diretório.
- Se o pod não voltar: `crictl ps -a | grep scheduler` e `crictl logs <id>`, ou `journalctl -u kubelet | tail` (erro de YAML aparece no kubelet).

Docs: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/ · https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md

---

## Q2 (Médio) — apiserver + PKI + etcd data dir

### 1 e 2. kube-apiserver

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kube-apiserver.yaml.bak   # backup FORA de manifests/
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
  - command:
    - kube-apiserver
    - --profiling=false                 # era true
    - --advertise-address=...
    - --authorization-mode=Node,RBAC    # era AlwaysAllow
    ...
```

```bash
# aguarde o apiserver voltar (30-60s)
watch crictl ps | grep apiserver
kubectl get --raw=/readyz
kubectl auth can-i list secrets -n kube-system --as=system:serviceaccount:default:default   # deve ser "no"
```

**Por quê:** `AlwaysAllow` desliga a autorização — qualquer identidade autenticada (inclusive qualquer ServiceAccount) pode fazer tudo. `Node` restringe o que cada kubelet pode ler (só objetos dos pods do seu node) e `RBAC` aplica Roles/ClusterRoles.

### 3 e 4. /etc/kubernetes/pki

```bash
find /etc/kubernetes/pki ! -user root -o ! -group root   # quem está errado
chown -R root:root /etc/kubernetes/pki

find /etc/kubernetes/pki -name '*.key' -exec stat -c '%a %n' {} \;
find /etc/kubernetes/pki -name '*.key' -exec chmod 600 {} +
```

**Por quê:** as chaves privadas (CA, sa.key que assina tokens de ServiceAccount, chaves de cliente) permitem forjar identidades no cluster. Qualquer usuário local com leitura em `ca.key` ou `sa.key` vira cluster-admin.

### 5. Data dir do etcd

```bash
grep data-dir /etc/kubernetes/manifests/etcd.yaml     # --data-dir=/var/lib/etcd
stat -c '%a %U:%G' /var/lib/etcd
chmod 700 /var/lib/etcd
```

(CIS 1.1.11. O 1.1.12 pede dono `etcd:etcd`; em kubeadm o etcd roda como root e não existe usuário etcd — não é cobrado aqui.)

### 6. kube-bench

```bash
mkdir -p /opt/course/02/q2
kube-bench run --targets master > /opt/course/02/q2/kube-bench-master.txt
grep -E 'profiling|AlwaysAllow|PKI' /opt/course/02/q2/kube-bench-master.txt
```

### Pegadinhas
- Depois de editar o manifest do apiserver, `kubectl` fica fora do ar por ~30-60 s. Não entre em pânico; use `crictl ps -a | grep kube-apiserver` e `crictl logs`. Se o container nem aparece, o erro é de YAML: `journalctl -u kubelet | grep -i apiserver` ou veja `/var/log/pods/kube-system_kube-apiserver-*`.
- `--authorization-mode=RBAC` sem `Node` funciona, mas falha o CIS (o kubelet ficaria com permissões do grupo `system:nodes` via RBAC, sem a restrição do Node authorizer). O benchmark pede os dois.
- Não use `chmod -R 600 /etc/kubernetes/pki`: isso tira o `x` dos diretórios. Mude só os arquivos `*.key`.
- `anonymous-auth=false` no apiserver aparece como achado no kube-bench, mas em kubeadm ele quebra as probes de liveness (que batem em `/livez` sem credencial). Na prova só mude se for pedido explicitamente.

Docs: https://kubernetes.io/docs/reference/access-authn-authz/authorization/ · https://kubernetes.io/docs/setup/best-practices/certificates/

---

## Q3 (Difícil) — kubelet + etcd + controller-manager

### 1. kube-bench antes

```bash
mkdir -p /opt/course/02/q3
kube-bench run --targets node > /opt/course/02/q3/kube-bench-node-before.txt
grep FAIL /opt/course/02/q3/kube-bench-node-before.txt
```

### 2. kubelet — descobrir de onde vem a configuração

```bash
ps aux | grep [k]ubelet
# /usr/bin/kubelet --bootstrap-kubeconfig=... --kubeconfig=/etc/kubernetes/kubelet.conf \
#   --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=... --anonymous-auth=true
systemctl cat kubelet          # mostra o drop-in 10-kubeadm.conf e os EnvironmentFile
```

O drop-in do kubeadm carrega `/var/lib/kubelet/kubeadm-flags.env` (`KUBELET_KUBEADM_ARGS`) e `/etc/default/kubelet` (`KUBELET_EXTRA_ARGS`). **Flags de linha de comando têm precedência sobre o arquivo de config.** É a pegadinha da questão: mesmo corrigindo o `config.yaml`, o `--anonymous-auth=true` em `/etc/default/kubelet` mantém o acesso anônimo.

Corrija o config file:

```bash
vim /var/lib/kubelet/config.yaml
```

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: false          # era true
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook             # era AlwaysAllow
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
...
readOnlyPort: 0             # era 10255 (ou apague a linha: o padrão no config file é 0)
```

Remova a flag que sobrescreve (ou troque para `--anonymous-auth=false`):

```bash
vim /etc/default/kubelet
# KUBELET_EXTRA_ARGS=""
systemctl daemon-reload
systemctl restart kubelet
systemctl status kubelet
```

Validar:

```bash
curl -sk https://127.0.0.1:10250/pods          # deve dar 401 Unauthorized
curl -s  http://127.0.0.1:10255/pods           # connection refused
kubectl get --raw /api/v1/nodes/controlplane/proxy/configz | python3 -m json.tool | grep -A3 -E 'anonymous|"mode"|readOnlyPort'
kubectl -n kube-system logs etcd-controlplane --tail=1   # apiserver -> kubelet continua ok
```

**Por quê:** com anonymous + AlwaysAllow, qualquer um que alcance a porta 10250 lista pods, lê logs e faz **exec** em containers (`/run`, `/exec`) — RCE no node. A porta 10255 (read-only, HTTP, sem auth) vaza a spec de todos os pods (env vars, às vezes segredos). Com `Webhook`, o kubelet pergunta ao apiserver (SubjectAccessReview) se a identidade pode acessar `nodes/proxy`, `nodes/log` etc.

### 3. Permissões

```bash
chmod 600 /var/lib/kubelet/config.yaml /etc/kubernetes/kubelet.conf
chown root:root /var/lib/kubelet/config.yaml /etc/kubernetes/kubelet.conf
```

(`kubelet.conf` tem a credencial do node; `config.yaml` define a postura de segurança do kubelet — ninguém além do root deve ler/alterar.)

### 4. etcd

```bash
vim /etc/kubernetes/manifests/etcd.yaml
```

```yaml
    - --client-cert-auth=true          # era false
    - --peer-client-cert-auth=true
```

**Por quê:** sem autenticação por certificado de cliente, quem alcança a 2379 lê/escreve diretamente o estado do cluster (todos os Secrets) sem passar pelo RBAC. CIS 2.2.

### 5. kube-controller-manager

```yaml
    - --use-service-account-credentials=true     # era false
```

**Por quê:** com `true`, cada controller roda com sua própria SA (`system:serviceaccount:kube-system:<controller>`) e as ClusterRoles mínimas `system:controller:*`; com `false`, todos usam a identidade do controller-manager (privilégios agregados). CIS 1.3.3.

### 6. kube-bench depois

```bash
# espere etcd/apiserver/controller-manager voltarem
kubectl -n kube-system get pod
kube-bench run --targets node > /opt/course/02/q3/kube-bench-node-after.txt
grep -E 'anonymous|authorization-mode|read-only|permissions' /opt/course/02/q3/kube-bench-node-after.txt
kube-bench run --targets etcd | grep client-cert-auth
```

### Pegadinhas
- **Flag x config file**: sempre olhe `ps aux | grep kubelet` e `systemctl cat kubelet`. Flags vencem o `config.yaml`.
- Esquecer `systemctl restart kubelet` (o kubelet não relê o config sozinho). Se mexeu em unit/drop-in, `systemctl daemon-reload` antes.
- Erro de YAML no `config.yaml` deixa o kubelet em crash loop: `journalctl -u kubelet -f`.
- Trocar o mode para `Webhook` sem `authentication.webhook.enabled: true` faz o apiserver perder acesso (logs/exec falham).
- Editar etcd derruba o apiserver por alguns segundos — espere antes de achar que quebrou.
- Se existir `node01`, a prova pode pedir o mesmo no worker: `ssh node01` e repita (o `kube-bench run --targets node` roda lá).

Docs: https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/ · https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/ · https://etcd.io/docs/latest/op-guide/security/
