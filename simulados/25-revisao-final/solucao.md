# Revisão final: soluções

> Abra só depois de tentar. Cronometre cada drill: o objetivo hoje é **velocidade**.

---

## D1: Falco, override de regra + file_output

### Passo a passo

```bash
systemctl list-units | grep falco             # nome do serviço (falco-modern-bpf, ...)
grep -n -A12 'rule: Terminal shell in container' /etc/falco/falco_rules.yaml   # só para ver a regra
```

`/etc/falco/falco_rules.local.yaml`:

```yaml
- rule: Terminal shell in container
  output: "%evt.time,%container.id,%user.name,%proc.name"
  priority: CRITICAL
  override:
    output: replace
    priority: replace
```

> Se o `override:` der erro na sua versão, **copie a regra inteira** do `falco_rules.yaml` para o
> `falco_rules.local.yaml` e edite `output`/`priority`. Uma regra com o mesmo nome carregada depois
> substitui a anterior. Esse método funciona em qualquer versão.

Saída em arquivo, em `/etc/falco/falco.yaml` (ou num drop-in em `/etc/falco/config.d/`):

```yaml
file_output:
  enabled: true
  keep_alive: false
  filename: /var/log/falco/alerts.log
```

```bash
mkdir -p /var/log/falco                 # o Falco NÃO cria o diretório
systemctl restart falco-modern-bpf
journalctl -u falco-modern-bpf -n 20    # procure erros de parsing das regras
kubectl -n d1 exec -it webshell -- sh   # dispara o alerta
tail /var/log/falco/alerts.log
```

### Pegadinhas
- A ordem de carga é `falco_rules.yaml` e depois `falco_rules.local.yaml`, por isso o override precisa estar no local.
- `json_output` deve continuar `false` (o enunciado pede texto).
- Sem `-it` não existe TTY e a regra não dispara (`proc.tty != 0`).

---

## D2: Falco, regra customizada + caça

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Package management in container
  desc: Gerenciador de pacotes executado dentro de container
  condition: spawned_process and container and proc.name in (apk, apt, apt-get, dpkg, yum, dnf)
  output: "%evt.time,%container.id,%container.image.repository,%proc.name"
  priority: ERROR
```

```bash
systemctl restart falco-modern-bpf && journalctl -u falco-modern-bpf -n 10

mkdir -p /opt/course/25/d2
timeout 35 journalctl -fu falco-modern-bpf -o cat | grep --line-buffered 'Error' > /opt/course/25/d2/falco.log
cut -d, -f2 /opt/course/25/d2/falco.log | sort -u     # container IDs

crictl ps --id <container_id>                          # mostra o nome do pod
crictl inspect <container_id> | grep -E 'io.kubernetes.pod.(name|namespace)'
# pod reports-7d9f...-abcde  →  Deployment reports (ou veja ownerReferences → ReplicaSet → Deployment)

kubectl -n store  scale deploy reports  --replicas 0
kubectl -n legacy scale deploy importer --replicas 0
printf 'store/reports\nlegacy/importer\n' > /opt/course/25/d2/report.txt
```

### Pegadinhas
- `store/updater` só **lista** `/sbin/apk`, mas não o executa. Por isso usamos `spawned_process` e `proc.name`, e não caminho de arquivo.
- `spawned_process` e `container` são macros do arquivo padrão. Não precisa redefinir.
- Na prova, a saída pode estar em `journalctl`, em `/var/log/syslog` ou ser preciso rodar `falco` manualmente. Verifique como o serviço está configurado.

---

## D3: Cilium toFQDNs

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: crawler-egress
  namespace: d3
spec:
  endpointSelector:
    matchLabels:
      app: crawler
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toFQDNs:
    - matchName: kubernetes.io
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toEndpoints:
    - matchLabels:
        app: cache
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
```

```bash
kubectl -n d3 exec crawler -- curl -sI -m5 https://kubernetes.io | head -1   # OK
kubectl -n d3 exec crawler -- curl -sI -m5 https://example.com               # timeout
```

### Pegadinhas
- **Sem a regra `dns:`** (L7 DNS) o Cilium não descobre os IPs do FQDN e o `toFQDNs` nunca libera nada. Esse é o erro mais comum.
- `matchName` é nome exato. `matchPattern: "*.kubernetes.io"` não cobre `kubernetes.io`.
- `toEndpoints` sem label de namespace fica restrito ao namespace da própria CNP.

---

## D4: Deny + Clusterwide

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: db-deny
  namespace: d4
spec:
  endpointSelector:
    matchLabels:
      app: db
  ingressDeny:
  - fromEndpoints:
    - matchLabels:
        app: debug                                     # implícito: namespace d4
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: d4-other      # qualquer pod de d4-other
---
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: debug-deny-world
spec:
  endpointSelector:
    matchLabels:
      role: debug                                      # em CCNP vale para todos os namespaces
  egress:
  - toEntities:
    - all                                              # sem isso → default-deny de egress (DNS quebra)
  egressDeny:
  - toEntities:
    - world
```

### Por quê
- **Deny sempre vence allow.** Por isso dá para "fechar" o que a `legacy-allow-all` abre sem mexer nela.
- Uma política que seleciona um endpoint coloca aquela direção em **default-deny**, inclusive quando só tem regras de deny.
  Por isso a CCNP precisa do `egress: toEntities: [all]`. Nas versões novas do Cilium, outra opção é
  `enableDefaultDeny: {egress: false}`.
- No `db-deny` isso não é necessário, porque a `legacy-allow-all` já libera o ingress.
- `kubectl get ccnp` (cluster-scoped, sem `-n`).

---

## D5: apiserver quebrado + audit

### Diagnóstico

```bash
crictl ps -a | grep kube-apiserver             # Exited / restartando
crictl logs <id>                                # ou:
tail /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log
# Error: unknown flag: --enable-admission-plugin
# (depois de corrigir) ... open /etc/kubernetes/audit/policy.yaml: no such file or directory
```

### Correção

```bash
mkdir -p /etc/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- RequestReceived
rules:
- level: Metadata              # PRIMEIRO: secrets de qualquer ns, incluindo d5
  resources:
  - group: ""
    resources: ["secrets"]
- level: RequestResponse
  namespaces: ["d5"]
- level: None
EOF
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kas-d5.yaml   # backup FORA de manifests/
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --enable-admission-plugins=NodeRestriction        # corrigir o "s"
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxbackup=2
    - --audit-log-maxage=5
    - --audit-log-maxsize=50
...
    volumeMounts:
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
...
  volumes:
  - name: audit-policy
    hostPath:
      path: /etc/kubernetes/audit/policy.yaml
      type: File
  - name: audit-log
    hostPath:
      path: /var/log/kubernetes/audit/
      type: DirectoryOrCreate
```

```bash
watch crictl ps          # espere 1–2 min sem mexer
tail -1 /var/log/kubernetes/audit/audit.log
```

### Pegadinhas
- **A primeira regra que casa é a que vale.** Se `namespaces: [d5]` vier antes, as secrets de d5 vão para RequestResponse e o conteúdo delas vaza no log.
- Sem os **volumes**, o container não enxerga a policy e o log fica dentro do container, não no host.
- Se o apiserver nem aparece no `crictl ps -a`, o problema é YAML inválido: `journalctl -u kubelet | tail`.

---

## D6: PSA restricted + hardening

```bash
kubectl label ns d6 pod-security.kubernetes.io/enforce=restricted
# Os Warnings listam quem viola: legacy-root e os pods atuais do web
kubectl -n d6 delete pod legacy-root --force --grace-period 0
kubectl -n d6 create sa web-sa
kubectl -n d6 patch sa web-sa -p '{"automountServiceAccountToken": false}'
kubectl -n d6 edit deploy web
```

```yaml
    spec:
      serviceAccountName: web-sa
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports: [{containerPort: 8080}]
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

```bash
kubectl -n d6 rollout status deploy web
kubectl -n d6 get events --sort-by=.lastTimestamp | tail     # se travar: "violates PodSecurity ..."
```

### Pegadinhas
- O PSA **não remove** Pods existentes, só avisa (warning). Pods que violam precisam ser apagados na mão.
- Com `enforce`, um Deployment que viola não mostra erro no `kubectl apply`. O erro fica no **ReplicaSet**
  (`kubectl -n d6 describe rs`). Na prova, quando aparece 0/2 sem pods, é aqui que se olha.
- Os 4 itens do restricted que mais caem: `runAsNonRoot`, `allowPrivilegeEscalation: false`, `drop: [ALL]` e `seccompProfile`.

---

## D7: Encryption at rest

```bash
mkdir -p /etc/kubernetes/enc
KEY=$(head -c 32 /dev/urandom | base64)
cat > /etc/kubernetes/enc/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: $KEY
  - identity: {}
EOF
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/kas-d7.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
...
    volumeMounts:
    - mountPath: /etc/kubernetes/enc
      name: enc
      readOnly: true
...
  volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

```bash
watch crictl ps
kubectl -n d7 get secrets -o json | kubectl replace -f -      # reescreve = criptografa as antigas

ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/secrets/d7/db-creds > /opt/course/25/d7/etcd.txt
grep -a k8s:enc /opt/course/25/d7/etcd.txt
# Sem etcdctl no host: crictl exec $(crictl ps --name etcd -q) etcdctl <mesmas flags> get ...
```

### Pegadinhas
- **A ordem dos providers importa:** o primeiro é o que **escreve**. Com `identity` primeiro, nada é criptografado.
- Secrets antigas só passam a ser criptografadas quando são **regravadas** (`replace`).
- O caminho da chave no etcd é `/registry/secrets/<namespace>/<nome>`.
- Os certificados do etcd ficam no próprio manifest: `grep etcd /etc/kubernetes/manifests/kube-apiserver.yaml`.
