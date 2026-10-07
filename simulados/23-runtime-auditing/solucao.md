# Auditing — Soluções

Conceitos-chave (valem para as 3 questões):

- **Stages**: `RequestReceived` → `ResponseStarted` (só long-running, ex. watch) → `ResponseComplete` → `Panic`. Sem `omitStages: [RequestReceived]`, cada requisição gera **dois** eventos.
- **Levels**: `None` < `Metadata` (quem, quando, o quê — sem corpo) < `Request` (+ corpo da requisição) < `RequestResponse` (+ corpo da resposta).
- As regras são avaliadas **em ordem**; vale a **primeira** que casar. Regras específicas primeiro, catch-all por último.
- Secrets/ConfigMaps/TokenReviews **nunca** devem ir com `Request`/`RequestResponse`: o valor do segredo vai parar no log.
- O kube-apiserver só lê a policy **na inicialização**. Alterou a policy → reinicie o apiserver.

Como reiniciar o apiserver (static pod) com segurança:

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak   # backup FORA de manifests/
mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/ && sleep 20 && mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
watch crictl ps --name kube-apiserver
```

---

## Q1 (Fácil) — Habilitar audit logging

### Passo a passo

```bash
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxbackup=2
    - --audit-log-maxsize=50
    ...
    volumeMounts:
    - mountPath: /etc/kubernetes/audit/policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes/audit/
      name: audit-log
      readOnly: false
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

(O bloco de volumes/volumeMounts está pronto na doc "Auditing" → seção "Log backend" — copie de lá.)

### Validar

```bash
crictl ps --name kube-apiserver          # novo container
k get --raw=/readyz
k create cm x --from-literal=a=b && tail -1 /var/log/kubernetes/audit/audit.log | jq .
```

### Pegadinhas
- `maxage` = **dias**; `maxbackup` = número de arquivos; `maxsize` = **MB**.
- Sem o volume do **diretório de log**, o apiserver grava dentro do container (some no restart e não aparece no host). Sem o volume da policy, o apiserver não sobe (`no such file or directory`).
- `type: File` para a policy exige que o arquivo exista; para o diretório de log use `DirectoryOrCreate`.
- Montar a policy como **arquivo** tem um efeito colateral: editar com `vim` troca o inode e o container continua vendo o arquivo antigo até recriar o pod. Montar o **diretório** evita isso.

Docs: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#log-backend

---

## Q2 (Médio) — Policy com regras ordenadas

### Policy

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # 1) Secrets SEMPRE em Metadata — precisa vir ANTES da regra de nodes
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]

  # 2) leituras dos nodes (kubelets) não são logadas
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get", "watch", "list"]

  # 3) endpoints nunca
  - level: None
    resources:
    - group: ""
      resources: ["endpoints"]

  # 4) deployments em prod com corpo completo
  - level: RequestResponse
    namespaces: ["prod"]
    resources:
    - group: "apps"
      resources: ["deployments"]

  # 5) catch-all
  - level: Metadata
```

```bash
vim /etc/kubernetes/audit/policy.yaml
# reiniciar o apiserver (a policy só é lida no start)
mv /etc/kubernetes/manifests/kube-apiserver.yaml /root/ ; sleep 20 ; mv /root/kube-apiserver.yaml /etc/kubernetes/manifests/
k get --raw=/readyz
```

### Validar manualmente

```bash
k -n prod create deploy t --image=nginx
tail -f /var/log/kubernetes/audit/audit.log | jq -c 'select(.objectRef.resource=="deployments") | {level, verb, ns: .objectRef.namespace, stage}'
jq -c 'select(.user.groups // [] | index("system:nodes")) | {verb, r: .objectRef.resource}' /var/log/kubernetes/audit/audit.log | tail
```

### Pegadinhas
- **Ordem**: se a regra `system:nodes → None` vier antes de Secrets, o `get secret` do kubelet não é logado — viola o item 2.
- Deployments são do grupo **`apps`**, não `""`. Com `group: ""` a regra nunca casa.
- `namespaces:` só se aplica a recursos namespaced.
- `userGroups` (grupos) ≠ `users` (usuários, ex.: `system:kube-proxy`).
- Esquecer o catch-all faz todo o resto não ser logado (o padrão quando nenhuma regra casa é `None`).

Docs: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy · referência dos campos: https://kubernetes.io/docs/reference/config-api/apiserver-audit.v1/#audit-k8s-io-v1-PolicyRule

---

## Q3 (Difícil) — Investigação + remediação + redução do log

### 1–3. Investigação com `jq`

Quem alterou (verbos de escrita: `patch`, `update`, `delete`):

```bash
LOG=/var/log/kubernetes/audit/audit.log
jq -c 'select(.objectRef.resource=="secrets" and .objectRef.name=="db-credentials"
              and (.verb=="patch" or .verb=="update" or .verb=="delete"))
       | {stage, verb, user: .user.username, code: .responseStatus.code, t: .requestReceivedTimestamp}' $LOG
```

Sem `omitStages`, cada requisição aparece duas vezes (`RequestReceived` e `ResponseComplete`) com o **mesmo** `requestReceivedTimestamp`; o `responseStatus` só existe no `ResponseComplete`.

```bash
mkdir -p /opt/course/23/q3
echo "system:serviceaccount:apps:ci-runner" > /opt/course/23/q3/user.txt
echo "<requestReceivedTimestamp>"           > /opt/course/23/q3/time.txt
```

Leituras **com sucesso** (`code == 200`) por ServiceAccounts:

```bash
jq -r 'select(.stage=="ResponseComplete" and .objectRef.resource=="secrets"
              and .objectRef.name=="db-credentials" and .verb=="get"
              and .responseStatus.code==200)
       | .user.username' $LOG | grep '^system:serviceaccount:' | sort -u > /opt/course/23/q3/readers.txt
cat /opt/course/23/q3/readers.txt
# system:serviceaccount:apps:ci-runner
# system:serviceaccount:vault:backup-agent
```

(`vault:monitoring` tentou, mas recebeu 403. O `list` de secrets feito pelo ci-runner não tem `objectRef.name`.)

Sem `jq`: `grep db-credentials $LOG | grep '"verb":"patch"' | grep ResponseComplete`.

### 4. Remediação

```bash
k get rolebinding -A -o wide | grep ci-runner
# vault   vault-maintenance   Role/secret-manager ...  apps/ci-runner
k -n vault delete rolebinding vault-maintenance
k -n apps delete sa ci-runner
k auth can-i patch secrets -n vault --as=system:serviceaccount:apps:ci-runner   # no
```

Não apague a Role `secret-manager` às cegas sem checar se outros bindings a usam; não mexa em `backup`, `observability`, `deployer`.

Bônus de resposta a incidente (fora do escopo do verify): rotacionar a senha do banco, e lembrar que o log antigo contém o valor do Secret em texto (base64) por causa do nível `RequestResponse` — proteja/expurgue esse arquivo.

### 5–8. Policy reduzida

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]
  - level: None
    verbs: ["get", "list", "watch"]
  - level: Metadata
```

Reinicie o apiserver e confira:

```bash
k get --raw=/readyz
k -n vault create secret generic t --from-literal=a=b
tail -5 /var/log/kubernetes/audit/audit.log | jq -c '{level, stage, verb, r: .objectRef.resource}'
```

### Pegadinhas
- Responder com o nome curto (`ci-runner`) quando foi pedido o username **do log** (`system:serviceaccount:apps:ci-runner`).
- Pegar o timestamp de um `get` em vez do `patch`, ou de outro Secret (`api-key` também foi alterado — pelo admin).
- Contar o 403 da `monitoring` como leitura.
- Remover só a SA e esquecer o RoleBinding (se a SA for recriada com o mesmo nome, ganha o acesso de volta).
- Alterar a policy e não reiniciar o apiserver.

Docs: https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
