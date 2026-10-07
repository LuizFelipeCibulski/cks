# Soluções — Secrets e Encryption at rest

> Conceitos-chave
> - Secret ≠ criptografia: `data` é apenas **base64**. Sem configuração extra, o apiserver grava o Secret no etcd em texto puro (protobuf). Quem lê o etcd (ou um backup dele) lê os Secrets.
> - Quem consegue `get secret` num namespace — ou **criar Pods** nele (pode montar qualquer Secret do namespace) — consegue ler os Secrets. RBAC sobre Secrets e sobre criação de Pods é crítico.
> - Formas de consumo: env (`secretKeyRef` / `envFrom`) ou volume (arquivos; atualizados automaticamente quando o Secret muda, exceto com `subPath`). Env aparece em `/proc/<pid>/environ` e em dumps; volume costuma ser preferido.
> - Tokens de ServiceAccount atuais são **projetados** (JWT com expiração, vinculado ao Pod) em `/var/run/secrets/kubernetes.io/serviceaccount/token`.
> - `EncryptionConfiguration`: o **primeiro** provider da lista cifra as gravações; **todos** são tentados na leitura. `identity` = sem cifra.

---

## Q1 (Fácil)

```bash
k -n vault-app create secret generic db-credentials \
  --from-literal=username=appuser --from-literal='password=Sup3r-S3cr3t!'     # aspas simples por causa do "!"
k -n vault-app run app --image=busybox:1.36 --dry-run=client -o yaml -- sleep 1d > app.yaml
```

Edite `app.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: vault-app
spec:
  containers:
  - name: app
    image: busybox:1.36
    args: ["sleep", "1d"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    volumeMounts:
    - name: creds
      mountPath: /etc/db-credentials
      readOnly: true
  volumes:
  - name: creds
    secret:
      secretName: db-credentials
```

```bash
k apply -f app.yaml
k -n vault-app exec app -- env | grep DB_USER
k -n vault-app exec app -- ls /etc/db-credentials        # password  username
```

Pegadinhas:
- `echo "Sup3r-S3cr3t!"` no bash interativo dispara history expansion — use aspas simples.
- Criar com `--from-file` de um arquivo gerado com `echo` inclui `\n` no valor.
- O Pod fica `CreateContainerConfigError` se o Secret/chave não existir.

Doc: https://kubernetes.io/docs/concepts/configuration/secret/ (seções *Using Secrets as files from a Pod* / *as environment variables*)

---

## Q2 (Médio)

1) Achar a chave em vários Secrets:

```bash
k -n legacy get secrets -o yaml | grep -n admin-password        # ou:
k -n legacy get secrets -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.data}{"\n"}{end}' | grep admin-password
k -n legacy get secret db-auth -o jsonpath='{.data.admin-password}' | base64 -d > /opt/course/15/q2/admin-password.txt
```

2) Token visto de dentro do container:

```bash
k -n monitoring get pod agent -o jsonpath='{.spec.serviceAccountName}'      # agent-sa
k -n monitoring exec agent -- cat /var/run/secrets/kubernetes.io/serviceaccount/token > /opt/course/15/q2/sa-token.txt
# conferir o conteúdo do JWT (payload = 2º campo):
cut -d. -f2 /opt/course/15/q2/sa-token.txt | tr '_-' '/+' | base64 -d 2>/dev/null; echo
```

3) De onde vem `DB_PASS`:

```bash
k -n monitoring get pod agent -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_PASS")].valueFrom.secretKeyRef}'
# {"key":"p","name":"mon-store-7f3a"}
echo "mon-store-7f3a:$(k -n monitoring get secret mon-store-7f3a -o jsonpath='{.data.p}' | base64 -d)" > /opt/course/15/q2/db-pass.txt
# ou direto do container: k -n monitoring exec agent -- printenv DB_PASS
```

Pegadinhas:
- O Secret `grafana-admin` tem uma chave chamada `DB_PASS`, mas **não** é ele que alimenta a variável — confira o `secretKeyRef`.
- O token montado não é o mesmo que `k create token agent-sa` gera (este não tem o claim do Pod). Pegue de dentro do Pod.
- `kubectl get secret -o jsonpath='{.data.chave-com-hifen}'` funciona; para chaves com ponto, escape: `{.data.tls\.crt}`.
- O token é JWT (não base64 puro): não decodifique o arquivo inteiro.

---

## Q3 (Difícil) — EncryptionConfiguration

Problemas do rascunho: (a) `identity` está **em primeiro** → tudo continua sendo gravado em texto puro; (b) a chave `bWluaGEtY2hhdmU=` decodifica para 10 bytes — o apiserver **não sobe** com chave aescbc de tamanho inválido (aceita 16/24/32; a tarefa pede 32).

```bash
head -c 32 /dev/urandom | base64          # gera a chave
```

`/etc/kubernetes/etcd/ec.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <SAÍDA DO COMANDO ACIMA>
      - identity: {}      # fallback: permite ler os Secrets antigos ainda não cifrados
```

Apiserver:

```bash
mkdir -p /root/cks-backup && cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/cks-backup/kube-apiserver.yaml.pre-enc
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
    - --encryption-provider-config=/etc/kubernetes/etcd/ec.yaml
...
    volumeMounts:
    - mountPath: /etc/kubernetes/etcd
      name: etcd-enc
      readOnly: true
...
  volumes:
  - hostPath:
      path: /etc/kubernetes/etcd
      type: DirectoryOrCreate
    name: etcd-enc
```

```bash
watch crictl ps --name kube-apiserver
k get --raw=/readyz
# troubleshooting: crictl ps -a | grep apiserver; crictl logs <id>; tail /var/log/pods/kube-system_kube-apiserver*/kube-apiserver/*.log
```

Re-cifrar tudo o que já existe (reescrever cada objeto faz o apiserver gravá-lo com o primeiro provider):

```bash
k get secrets -A -o json | k replace -f -
```

Provar no etcd:

```bash
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
  get /registry/secrets/bank/bank-creds > /opt/course/15/q3/etcd-bank-creds.txt
hexdump -C /opt/course/15/q3/etcd-bank-creds.txt | head
# ... k8s:enc:aescbc:v1:key1: <bytes ilegíveis>   (antes aparecia "C0fr3-F0rt3!" em claro)
k -n bank get secret bank-creds -o jsonpath='{.data.pass}' | base64 -d       # API continua lendo normalmente
```

Pegadinhas:
- **Ordem dos providers**: o primeiro cifra. Com `identity` primeiro, nada é cifrado (apesar do apiserver subir).
- **Sem `identity` como fallback** antes de re-cifrar: o apiserver não consegue ler Secrets antigos (erros em `k get secrets`).
- **Esquecer o volume/volumeMount**: apiserver não sobe ("no such file or directory").
- Nunca deixe a cópia de backup dentro de `/etc/kubernetes/manifests`.
- A chave no YAML é base64 de bytes aleatórios — não confunda com o tamanho da string base64.
- `aesgcm` exige rotação frequente de chave; `secretbox` (XSalsa20+Poly1305, chave de 32 bytes) e `aescbc` são as opções locais comuns; KMS v2 é o recomendado em produção (a chave no arquivo do controlplane é o ponto fraco).
- Para conferir quais Secrets ainda estão em texto puro: `etcdctl get /registry/secrets/<ns>/<nome> | grep -a k8s:enc || echo PLAINTEXT`.

Docs:
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
