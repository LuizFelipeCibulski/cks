# Soluções — Pod Security Standards / Pod Security Admission

> Conceitos-chave
> - O **Pod Security Admission (PSA)** é um admission controller nativo (habilitado por padrão desde a v1.25) que aplica os **Pod Security Standards**: `privileged` (sem restrições), `baseline` (bloqueia escaladas conhecidas: privileged, hostPID/hostNetwork/hostIPC, hostPath, hostPort, capabilities extras etc.) e `restricted` (baseline + boas práticas: runAsNonRoot, seccomp, drop ALL, allowPrivilegeEscalation=false, só alguns tipos de volume).
> - É configurado por **labels no namespace**: `pod-security.kubernetes.io/<MODO>=<NÍVEL>` e `pod-security.kubernetes.io/<MODO>-version=<VERSÃO>`, onde MODO ∈ `enforce` (rejeita), `audit` (anota o evento de auditoria), `warn` (mostra aviso ao usuário).
> - **Enforce só vale para Pods**, não para Deployments/ReplicaSets. O Deployment é aceito; quem falha é o ReplicaSet ao tentar criar o Pod → o erro aparece nos **eventos do ReplicaSet** (`kubectl describe rs`). `warn` e `audit`, por outro lado, também avaliam os templates de workloads.
> - Pods que **já existem** não são removidos quando você aplica enforce; o `kubectl label` só mostra um *warning* com os Pods que violariam.

---

## Q1 (Fácil) — enforce baseline + warn restricted

```bash
k label ns team-blue \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted

k apply -f /opt/course/13/q1/pod.yaml 2>&1 | tee /opt/course/13/q1/error.txt
# Error from server (Forbidden): error when creating "/opt/course/13/q1/pod.yaml": pods "node-debugger" is forbidden:
# violates PodSecurity "baseline:latest": privileged (container "debugger" must not set securityContext.privileged=true)
```

Por quê: `privileged: true` dá ao container acesso a todos os devices e capabilities do host — praticamente root no nó. `baseline` bloqueia isso.

Pegadinhas:
- O erro vai para **stderr**: use `2>&1` (ou `&>`) antes de redirecionar, senão o arquivo fica vazio.
- Se errar o valor da label (ex.: `Baseline`), o `kubectl label` aceita, mas o PSA ignora/avisa. Valores são minúsculos.
- O Pod `inventory` (nginx comum) continua rodando: enforce não afeta pods existentes.

Validação: `k get ns team-blue --show-labels`; `k apply -f pod.yaml --dry-run=server`.

Doc: https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

---

## Q2 (Médio) — vários modos/versões e descobrir violadores

Dica de velocidade: aplique primeiro com `--dry-run=server` — o apiserver lista os Pods que violariam o nível:

```bash
k label --dry-run=server --overwrite ns apps-prod pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "apps-prod" violate the new PodSecurity enforce level "restricted:latest"
# Warning: backend: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
# Warning: cache: seccompProfile
# Warning: debug: host namespaces
```

Aplicando de fato:

```bash
k label ns apps-prod --overwrite \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.34 \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest

k label ns apps-dev --overwrite \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest

printf "backend\ncache\ndebug\n" > /opt/course/13/q2/violations.txt
k -n apps-prod delete pod backend cache debug --force --grace-period=0   # --force só para acelerar
```

Por que cada um viola `restricted`:
- `backend`: nenhum securityContext (roda como root, sem seccomp, com capabilities padrão, permite escalada).
- `cache`: quase tudo certo, **mas sem `seccompProfile`** (RuntimeDefault ou Localhost são exigidos no restricted) — pegadinha clássica.
- `debug`: `hostNetwork: true` (viola até o baseline).
- `frontend` e `metrics` estão completos: runAsNonRoot, seccomp RuntimeDefault, drop ALL, allowPrivilegeEscalation=false.

Pegadinhas:
- Fixar versão (`enforce-version=v1.34`) protege contra mudanças de regra em upgrades; `latest` acompanha a versão do cluster.
- Rodar o `label` duas vezes com o mesmo nível não mostra warnings de novo (o PSA só avalia pods quando a política muda).

Validação:
```bash
k -n apps-prod run t --image=busybox:1.36 --dry-run=server -- sleep 1      # Forbidden restricted:v1.34
k -n apps-dev run t --image=busybox:1.36 --dry-run=server -- sleep 1       # created + Warning restricted
```

Doc: https://kubernetes.io/docs/concepts/security/pod-security-admission/#pod-security-admission-labels-for-namespaces

---

## Q3 (Difícil) — enforce restricted, troubleshooting do ReplicaSet, corrigir Deployment e AdmissionConfiguration

### Parte A

```bash
k label ns checkout pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest
k -n checkout rollout restart deploy checkout-api
k -n checkout get deploy,rs,pod            # novo RS com DESIRED 1 e CURRENT 0
k -n checkout describe rs $(k -n checkout get rs --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2) | tail
# ou: k -n checkout get events --field-selector reason=FailedCreate
k -n checkout get events --field-selector reason=FailedCreate -o jsonpath='{.items[-1].message}' > /opt/course/13/q3/reason.txt
cat /opt/course/13/q3/reason.txt
# Error creating: pods "checkout-api-xxxx" is forbidden: violates PodSecurity "restricted:latest": privileged (container "init-config" ...),
# allowPrivilegeEscalation != false (...), unrestricted capabilities (...), restricted volume types (volume "logs" uses restricted volume type "hostPath"),
# runAsNonRoot != true (...), runAsUser=0 (container "api" must not set runAsUser=0), seccompProfile (...)
```

Os Pods antigos continuam de pé (o rollout novo não avança) — por isso a aplicação "parece" ok, mas qualquer reschedule quebraria.

Corrigindo: `k -n checkout edit deploy checkout-api` deixando o template assim:

```yaml
    spec:
      securityContext:              # nível de Pod: vale para TODOS os containers, inclusive init
        runAsNonRoot: true
        runAsUser: 101              # busybox roda como root por padrão; sem um UID numérico o init falha com
                                    # "container has runAsNonRoot and image will run as root"
        seccompProfile:
          type: RuntimeDefault
      initContainers:
      - name: init-config
        image: busybox:1.36
        command: ["sh", "-c", "echo ready > /work/ready"]
        securityContext:
          allowPrivilegeEscalation: false      # e REMOVER privileged: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: work
          mountPath: /work
      containers:
      - name: api
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:                       # REMOVER runAsUser: 0 (o nível de container sobrescreve o de Pod!)
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: work
          mountPath: /work
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: work
        emptyDir: {}
      - name: logs
        emptyDir: {}                           # era hostPath
```

```bash
k -n checkout rollout status deploy checkout-api
k -n checkout exec deploy/checkout-api -c api -- wget -qO- 127.0.0.1:8080 | head -3
k -n checkout exec deploy/checkout-api -c api -- id     # uid=101
```

Pegadinhas:
- **initContainers também são avaliados** — fácil esquecer o `privileged: true` do init.
- `runAsUser: 0` no container sobrescreve o `runAsNonRoot`/`runAsUser` do Pod → continua violando.
- `runAsNonRoot: true` com imagem cujo USER é root (ou não numérico) → Pod fica em `CreateContainerConfigError`. Defina `runAsUser` numérico.
- nginx comum (`nginx:1.27-alpine`) não roda como não-root na porta 80; por isso a imagem `nginx-unprivileged` (porta 8080, UID 101).
- Restricted só permite volumes: configMap, csi, downwardAPI, emptyDir, ephemeral, persistentVolumeClaim, projected, secret.

### Parte B — AdmissionConfiguration no kube-apiserver

```bash
mkdir -p /root/cks-backup /etc/kubernetes/psa
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/cks-backup/kube-apiserver.yaml.$(date +%s)   # backup FORA de manifests/

cat > /etc/kubernetes/psa/podsecurity.yaml <<'YAML'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "restricted"
      audit-version: "latest"
      warn: "baseline"
      warn-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces: ["kube-system", "legacy-batch"]
YAML
```

`vim /etc/kubernetes/manifests/kube-apiserver.yaml`:

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --admission-control-config-file=/etc/kubernetes/psa/podsecurity.yaml
    ...
    volumeMounts:
    - mountPath: /etc/kubernetes/psa
      name: psa
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/psa
      type: DirectoryOrCreate
    name: psa
```

```bash
watch crictl ps --name kube-apiserver        # espere o container reiniciar
k get --raw=/readyz
# se não subir: crictl ps -a --name kube-apiserver; crictl logs <id>; ou /var/log/pods/kube-system_kube-apiserver-*/
```

Testes:
```bash
k -n legacy-batch run p --image=busybox:1.36 --dry-run=server --overrides='{"spec":{"containers":[{"name":"p","image":"busybox:1.36","securityContext":{"privileged":true}}]}}'
# pod/p created (server dry run)  -> isento
k create ns tmp; k -n tmp run p --image=busybox:1.36 --dry-run=server --overrides='{"spec":{"hostPID":true}}'
# Warning: would violate PodSecurity "baseline:latest" ... + created
```

Por quê: os *defaults* valem para namespaces **sem** labels PSA; as labels do namespace têm precedência sobre os defaults. Já as **exemptions** ignoram completamente a avaliação (útil para namespaces de sistema, como CNI/CSI que precisam de privilégios) — por isso `legacy-batch` aceita Pod privilegiado mesmo com `enforce=restricted`.

Pegadinhas:
- Esquecer o `volumeMount`/`hostPath` → o apiserver não acha o arquivo e não sobe ("no such file or directory").
- `apiVersion` errado: o envelope é `apiserver.config.k8s.io/v1` e a configuração interna é `pod-security.admission.config.k8s.io/v1`.
- Nunca deixe cópias `.yaml` dentro de `/etc/kubernetes/manifests` (o kubelet tentaria subir um segundo apiserver).
- `--admission-control-config-file` é o mesmo arquivo usado por outros plugins (ex.: EventRateLimit, ImagePolicyWebhook): se já existir, **acrescente** o plugin na lista `plugins:`.

Docs:
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
