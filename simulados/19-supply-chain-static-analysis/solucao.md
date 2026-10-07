# Soluções — Supply Chain: Static Analysis (kubesec, KubeLinter, revisão manual)

> Conceito: **análise estática** encontra problemas de segurança **antes** do deploy, olhando só o texto do manifesto/Dockerfile (shift-left).
> - **kubesec**: dá um **score** ao objeto; itens `critical` (ex.: `privileged`, `hostPID`, `hostNetwork`, `CAP_SYS_ADMIN`) tornam o score negativo; itens de `advise` somam pontos (`readOnlyRootFilesystem`, `runAsNonRoot`, `runAsUser > 10000`, limits/requests, `capabilities.drop`, `serviceAccountName`...).
> - **KubeLinter**: lista de *checks* (padrão: `latest-tag`, `run-as-non-root`, `no-read-only-root-fs`, `privileged-container`, `privilege-escalation-container`, `unset-cpu-requirements`, `unset-memory-requirements`, `host-pid`, `host-network`, `sensitive-host-mounts`, `no-anti-affinity`, `env-var-secret`, `non-existent-service-account`, `dangling-service`...). Saída com código ≠ 0 se houver erros.
> - Revisão manual: o exame pode pedir para "achar os arquivos inseguros" sem ferramenta nenhuma.

Comandos úteis: `kubesec scan arq.yaml | jq '.[].scoring.critical'`, `kube-linter checks list`, `kube-linter lint arq.yaml`.

---

## Q1 (Fácil) — kubesec

```bash
cd /opt/course/19/q1
kubesec scan pod.yaml > kubesec-before.json
jq -r '.[0].score' kubesec-before.json                  # -48
jq -r '.[0].scoring.critical[].id' kubesec-before.json | tee critical.txt
# Privileged
# HostNetwork
# HostPID
```

Arquivo corrigido:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy-agent
  namespace: kubesec-lab
  labels:
    app: legacy-agent
spec:
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      privileged: false
      runAsNonRoot: true
      runAsUser: 10001            # > 10000 também pontua
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

```bash
kubesec scan pod.yaml | jq '.[0] | {score, critical: .scoring.critical}'   # score 5, critical null
k apply -f pod.yaml
k -n kubesec-lab get pod legacy-agent
```

### Por quê
- `privileged: true` dá ao container praticamente todas as capabilities e acesso aos devices do host; `hostPID` permite ver/sinalizar processos do nó (e ler `/proc/<pid>/environ` de outros containers); `hostNetwork` coloca o Pod na rede do nó (acesso a serviços em `localhost`, sniffing, bypass de NetworkPolicy).
- kubesec é um scanner de "pontuação": zerar os críticos é obrigatório; os pontos positivos vêm das recomendações listadas em `.scoring.advise`.

### Pegadinhas
- `kubesec scan` sai com código ≠ 0 quando há crítico — normal; o JSON vai para stdout mesmo assim.
- Remover `hostPID`/`hostNetwork` → simplesmente apague as linhas (ou `false`).
- Um Pod não aceita mudança de `securityContext` com `kubectl apply` em cima de um existente: `k replace --force -f pod.yaml`.
- `kubesec` também tem modo servidor/HTTP (`curl -sSX POST --data-binary @pod.yaml https://v2.kubesec.io/scan`) — na prova use o binário local.

Doc: https://kubesec.io/

---

## Q2 (Médio) — revisão manual + KubeLinter + Dockerfile

### 1) Arquivos inseguros
```bash
cd /opt/course/19/q2
cat deploy-a.yaml deploy-b.yaml pod-c.yaml
cat Dockerfile-1 Dockerfile-2 Dockerfile-3
cat > insecure-files.txt <<'EOF'
deploy-b.yaml
Dockerfile-2
Dockerfile-3
EOF
```

| Arquivo | Veredito | Motivo |
|---|---|---|
| deploy-a.yaml | OK | non-root, RO rootfs, drop ALL, sem escalonamento, seccomp, resources |
| deploy-b.yaml | **Inseguro** | `hostPID: true` + `hostPath: /` montado (acesso a todo o FS do nó: kubelet creds, `/etc/shadow`, etc.) — o resto "bonito" do securityContext é distração |
| pod-c.yaml | OK | a senha vem de `secretKeyRef` (correto), demais controles presentes |
| Dockerfile-1 | OK | multi-stage, distroless, USER 65532 |
| Dockerfile-2 | **Inseguro** | credenciais AWS em `ENV` → ficam no config da imagem e no `docker history` |
| Dockerfile-3 | **Inseguro** | `COPY id_rsa` deixa a chave privada numa camada da imagem; `USER root` no final faz o processo rodar como root |

### 2) KubeLinter
```bash
kube-linter lint /opt/course/19/q2/deploy-b.yaml > /opt/course/19/q2/kube-linter-b.txt
cat /opt/course/19/q2/kube-linter-b.txt
# ... (check: host-pid ...)
# ... (check: sensitive-host-mounts ...)
```
(O "Error: found 2 lint errors" vai para stderr; se quiser no arquivo também, use `&>`.)

### 3) Dockerfile-3 corrigido
```dockerfile
# syntax=docker/dockerfile:1
FROM node:20.11-alpine
WORKDIR /app
COPY package.json package-lock.json ./
# chave usada só durante o build, via SSH agent forwarding do BuildKit (não vira camada)
RUN --mount=type=ssh npm ci --omit=dev
COPY . .
RUN chown -R node:node /app
USER node
EXPOSE 3000
CMD ["node", "server.js"]
```
Build: `docker build --ssh default .` (ou `RUN --mount=type=secret,id=deploykey ...` + `docker build --secret id=deploykey,src=$HOME/.ssh/id_rsa .`).

### Por quê
- Tudo que é `COPY`/`ADD` vira camada: mesmo um `RUN rm /root/.ssh/id_rsa` posterior **não** remove a chave das camadas anteriores — qualquer um com `docker save` extrai.
- `USER` vale até o próximo `USER`; o **último** é o que define com quem o `CMD` roda.

### Pegadinhas
- A prova costuma esconder o problema em meio a várias boas práticas (deploy-b tem `runAsNonRoot`, `drop ALL`... e mesmo assim é inseguro).
- `env` com `secretKeyRef` é aceitável; `value:` em texto puro para senha não é.

Docs: https://docs.kubelinter.io/#/generated/checks — https://docs.docker.com/build/building/secrets/

---

## Q3 (Difícil) — kubesec >= 10 + KubeLinter limpo + deploy funcionando

### Investigação
```bash
cd /opt/course/19/q3
kube-linter lint deploy.yaml          # latest-tag, no-anti-affinity, no-read-only-root-fs, privilege-escalation-container,
                                      # privileged-container, run-as-non-root, unset-cpu/memory, env-var-secret
kubesec scan deploy.yaml | jq '.[] | {object, score, c: [.scoring.critical[]?.id]}'
```

### Manifesto corrigido
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog
  namespace: static-app
automountServiceAccountToken: false
---
apiVersion: v1
kind: Secret
metadata:
  name: catalog-api
  namespace: static-app
type: Opaque
stringData:
  api-secret: "s3cr3t-4p1-k3y-2024"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: static-app
  labels:
    app: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      serviceAccountName: catalog            # kubesec +3; precisa EXISTIR no arquivo p/ o kube-linter
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10101
        runAsGroup: 10101
        seccompProfile:
          type: RuntimeDefault
      affinity:                              # check no-anti-affinity (replicas > 1)
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: kubernetes.io/hostname
              labelSelector:
                matchLabels:
                  app: catalog
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        env:
        - name: API_SECRET
          valueFrom:
            secretKeyRef:
              name: catalog-api
              key: api-secret
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: tmp                          # nginx precisa escrever pid/cache em /tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: static-app
spec:
  selector:
    app: catalog
  ports:
  - name: http
    port: 80
    targetPort: 8080                         # a nova imagem escuta em 8080!
```

```bash
kube-linter lint deploy.yaml                                  # No lint errors found!
kubesec scan deploy.yaml | tee kubesec-final.json | jq '.[] | select(.object|startswith("Deployment")) | .score'   # 14
k apply -f deploy.yaml
k -n static-app rollout status deploy catalog
k -n static-app exec deploy/catalog -- wget -qO- catalog | head -4
```

### Por quê / pegadinhas
- **readOnlyRootFilesystem** quebra o nginx se não houver um `emptyDir` em `/tmp` (a imagem unprivileged grava `nginx.pid` e temporários lá). O Pod entra em `CrashLoopBackOff` — é a pegadinha mais comum.
- **Service targetPort**: trocar a imagem para a versão unprivileged (porta 8080, evita bind < 1024 como não-root) exige ajustar o `targetPort`, senão o Service fica sem resposta.
- **non-existent-service-account**: o kube-linter só "enxerga" os objetos do arquivo; se você referenciar um SA, inclua-o no arquivo.
- **env-var-secret**: o kube-linter marca variáveis cujo **nome contém `secret`** (regex `(?i).*secret.*`) com `value:` literal — use `secretKeyRef`. Atenção: `DB_PASSWORD` com valor literal **não** é pego pelo check padrão, mas continua sendo má prática (e a revisão manual da prova pega).
- **no-anti-affinity**: com `replicas > 1` é preciso `podAntiAffinity`. Use `preferred...` para não travar o agendamento em cluster de um só nó.
- **latest-tag**: imagem sem tag = `latest`.
- `kubesec` pontua `runAsUser > 10000` — por isso 10101 e não 101.
- Se não quiser seguir um check do kube-linter (não é o caso aqui), dá para ignorar por objeto com a annotation `ignore-check.kube-linter.io/<check>: "motivo"` ou usar um `.kube-linter.yaml` — mas a questão pede config padrão.

Docs:
- https://docs.kubelinter.io/#/generated/checks
- https://kubesec.io/
