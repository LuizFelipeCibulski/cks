# Immutability of containers at runtime — Soluções

Conceito: um container imutável não pode ser alterado depois de iniciado — se um atacante entrar, não consegue baixar ferramentas, alterar binários ou plantar persistência no filesystem. Ferramentas no Kubernetes:

- `securityContext.readOnlyRootFilesystem: true` (nível de **container**; não existe no nível do Pod);
- `emptyDir` só para os diretórios que realmente precisam de escrita (cache, pid, tmp);
- não rodar como root (`runAsUser`/`runAsNonRoot`), `privileged: false`, `allowPrivilegeEscalation: false`;
- imagens mínimas/distroless (sem shell, sem gerenciador de pacotes);
- garantir isso via admission (PSA, ValidatingAdmissionPolicy, OPA/Kyverno).

> **Truque antigo (killer.sh/cursos antigos):** usar um `startupProbe` com `rm /bin/sh /bin/bash` (ou `chmod -x`) para remover shells assim que o container sobe. Funciona como demonstração, mas não é a forma recomendada: altera o filesystem em runtime (o oposto de imutabilidade), quebra `kubectl exec` para debug e não impede um atacante de trazer o próprio binário se o FS for gravável. Prefira `readOnlyRootFilesystem` + imagem distroless. Se aparecer na prova, faça o que for pedido.

---

## Q1 (Fácil) — readOnlyRootFilesystem + emptyDir

```bash
k -n immutable edit deploy logger
```

```yaml
    spec:
      containers:
      - name: logger
        image: busybox:1.36
        command: [...]
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: logs
          mountPath: /app/logs
      volumes:
      - name: logs
        emptyDir: {}
```

Validar:

```bash
k -n immutable rollout status deploy logger
k -n immutable exec deploy/logger -- touch /x          # Read-only file system
k -n immutable exec deploy/logger -- tail -2 /app/logs/app.log
```

Pegadinhas:
- `readOnlyRootFilesystem` vai em `containers[].securityContext`, **não** em `spec.securityContext` (o apiserver rejeita/ignora no lugar errado).
- Não monte o emptyDir em `/app` inteiro nem em `/` — só no diretório que precisa de escrita.
- O kubelet cria o ponto de montagem `/app/logs` mesmo com o root read-only, então o `mkdir -p` do comando funciona.

Docs: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

## Q2 (Médio) — Descobrir quais paths precisam de escrita

### Investigação

```bash
k -n frontend get pod
k -n frontend logs deploy/web -c nginx
# nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)
k -n frontend logs deploy/web -c content
# sh: can't create /tmp/index.html.new: Read-only file system
```

O nginx morre (CrashLoopBackOff) ao criar seus diretórios de cache; depois de corrigir isso, ele morre de novo ao gravar o PID:

```
nginx: [emerg] open() "/var/run/nginx.pid" failed (30: Read-only file system)
```

O container `content` não morre (o loop continua), mas falha silenciosamente — só aparece nos logs. Por isso sempre olhe os logs de **todos** os containers.

### Correção

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
        - name: nginx-cache
          mountPath: /var/cache/nginx
        - name: nginx-run
          mountPath: /var/run        # em alpine /var/run -> /run; montar /run também funciona
      - name: content
        image: busybox:1.36
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: html
          mountPath: /html
        - name: content-tmp
          mountPath: /tmp
      volumes:
      - name: html
        emptyDir: {}
      - name: nginx-cache
        emptyDir: {}
      - name: nginx-run
        emptyDir: {}
      - name: content-tmp
        emptyDir: {}
```

Validar:

```bash
k -n frontend rollout status deploy web
k -n frontend exec deploy/web -c nginx -- wget -qO- localhost
```

Pegadinhas:
- Montar emptyDir em `/etc/nginx` ou `/var` "resolve", mas esconde a configuração/arquivos da imagem (e anula o propósito do read-only).
- A mensagem `can not modify /etc/nginx/conf.d/default.conf (read-only file system?)` do entrypoint é só informativa.
- Para nginx, na prova costuma bastar `/var/cache/nginx` e `/var/run` (às vezes `/tmp`).

---

## Q3 (Difícil) — Auditar Pods + ValidatingAdmissionPolicy

### 1. Levantar o estado de todos os Pods

```bash
for ns in orion pegasus lyra; do
  k -n $ns get pod -o custom-columns='NAME:.metadata.name,PODUSER:.spec.securityContext.runAsUser,RO:.spec.containers[*].securityContext.readOnlyRootFilesystem,PRIV:.spec.containers[*].securityContext.privileged,CUSER:.spec.containers[*].securityContext.runAsUser,INIT_RO:.spec.initContainers[*].securityContext.readOnlyRootFilesystem'
done
```

Confirme o UID efetivo direto no container (pega o caso "sem runAsUser = root da imagem"):

```bash
k -n lyra exec backend -- id -u          # 0
k -n pegasus exec batch -- id -u         # 0 (container sobrescreve o runAsUser do Pod)
```

Resultado:

| Pod | Motivo |
|---|---|
| orion/cache | sem readOnlyRootFilesystem |
| orion/scheduler | **initContainer** sem readOnlyRootFilesystem |
| pegasus/worker | privileged: true |
| pegasus/batch | container `runAsUser: 0` sobrescreve o `1000` do Pod |
| lyra/frontend | sidecar `log-agent` sem readOnlyRootFilesystem |
| lyra/backend | nenhum runAsUser → roda como root (padrão da imagem) |

Imutáveis: `orion/api`, `pegasus/metrics`, `pegasus/db`, `lyra/static`.

```bash
cat > /opt/course/24/q3/pods.txt <<EOF
orion/cache
orion/scheduler
pegasus/worker
pegasus/batch
lyra/frontend
lyra/backend
EOF
k -n orion delete pod cache scheduler --force --grace-period=0
k -n pegasus delete pod worker batch --force --grace-period=0
k -n lyra delete pod frontend backend --force --grace-period=0
```

### 2. ValidatingAdmissionPolicy

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-readonly-rootfs
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  variables:
  - name: allContainers
    expression: "object.spec.containers + (has(object.spec.initContainers) ? object.spec.initContainers : [])"
  validations:
  - expression: >-
      variables.allContainers.all(c,
        has(c.securityContext) &&
        has(c.securityContext.readOnlyRootFilesystem) &&
        c.securityContext.readOnlyRootFilesystem == true)
    message: "readOnlyRootFilesystem required"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-readonly-rootfs-binding
spec:
  policyName: require-readonly-rootfs
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: lyra
```

`kubernetes.io/metadata.name` é um label que o Kubernetes coloca automaticamente em todo namespace — ótimo para selecionar um namespace específico sem precisar criar labels.

Teste:

```bash
k -n lyra run t --image=busybox:1.36 --dry-run=server -- sleep 1     # negado
k -n orion run t --image=busybox:1.36 --dry-run=server -- sleep 1    # permitido
```

### 3. Recriar o frontend corrigido

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: lyra
  labels: {app: frontend}
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
  - name: log-agent
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /tmp/agent.log; sleep 5; done"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

```bash
k apply -f /opt/course/24/q3/frontend.yaml
k -n lyra exec frontend -c log-agent -- tail -2 /tmp/agent.log
```

### Pegadinhas
- Conferir só `containers` e esquecer `initContainers`.
- `runAsUser` no container **sobrescreve** o do Pod.
- Ausência de `runAsUser` = UID definido na imagem (busybox → root). `runAsNonRoot: true` faria o kubelet recusar iniciar.
- No CEL, acessar `c.securityContext.readOnlyRootFilesystem` sem `has()` gera erro de avaliação quando o campo não existe; com `failurePolicy: Fail` o Pod é negado, mas com a mensagem errada.
- Policies não afetam Pods já em execução — por isso a investigação manual.

Docs: https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
