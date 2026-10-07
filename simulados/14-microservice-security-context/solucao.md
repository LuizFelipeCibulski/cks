# Soluções — Security Context

> Conceitos-chave
> - `securityContext` existe em **dois níveis**: Pod (`spec.securityContext`: runAsUser, runAsGroup, runAsNonRoot, fsGroup, supplementalGroups, seccompProfile, sysctls...) e container (`spec.containers[].securityContext`: tudo do Pod que se aplica a processo **mais** privileged, allowPrivilegeEscalation, capabilities, readOnlyRootFilesystem, procMount).
> - Quando o mesmo campo está nos dois níveis, **o do container vence**.
> - `privileged: true` = todas as capabilities + acesso a todos os devices do host → equivale a root no nó. `hostPID`/`hostNetwork`/`hostIPC` quebram o isolamento de namespaces do kernel (ver processos/rede do nó, sniffar tráfego, `nsenter`).
> - `allowPrivilegeEscalation: false` liga o `no_new_privs` (bloqueia setuid/sudo). Note: ele é sempre true se o container for privileged ou tiver CAP_SYS_ADMIN.
> - `fsGroup`: o kubelet faz `chown`/`setgid` do volume para esse GID e adiciona o GID como grupo suplementar do processo.

---

## Q1 (Fácil)

`/opt/course/14/q1/pod.yaml` final:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: sec-ctx
  labels:
    app: secure-app
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

```bash
k apply -f /opt/course/14/q1/pod.yaml
k -n sec-ctx exec secure-app -- id            # uid=1000 gid=3000 groups=2000,3000
k -n sec-ctx exec secure-app -- touch /data/a && k -n sec-ctx exec secure-app -- ls -ln /data   # grupo 2000
k -n sec-ctx exec secure-app -- touch /etc/a  # Read-only file system
```

Pegadinhas:
- `fsGroup` **só existe no nível do Pod** — colocar no container dá erro de validação ("unknown field").
- `readOnlyRootFilesystem` e `capabilities` **só existem no nível do container**.
- Com rootfs read-only, a aplicação precisa de volumes (`emptyDir`) para tudo que grava (`/tmp`, cache, pid files).
- Exemplo pronto na doc: busque "security-context" → seção *Set the security context for a Pod* (`security-context.yaml`).

Doc: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

---

## Q2 (Médio) — achar e remover Pods privilegiados

Listar `namespace/pod` + flags de privileged de containers e initContainers:

```bash
k get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\t"}{.spec.initContainers[*].securityContext.privileged}{"\n"}{end}' \
  | grep '^team-' | grep true
# team-alpha/debug-tools        true
# team-beta/metrics-collector-xxxx-aaaa   true
# team-beta/metrics-collector-xxxx-bbbb   true
# team-gamma/bootstrap                    true   (initContainer!)

# alternativa com jq
k get pods -A -o json | jq -r '.items[] | select(.metadata.namespace|startswith("team-"))
  | select([.spec.containers[]?, .spec.initContainers[]?] | any(.securityContext.privileged==true))
  | "\(.metadata.namespace)/\(.metadata.name)"' > /opt/course/14/q2/privileged-pods.txt
```

Quem é dono de cada Pod?
```bash
k get pod -n team-beta -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind
```

```bash
k -n team-alpha delete pod debug-tools --force --grace-period=0
k -n team-gamma delete pod bootstrap --force --grace-period=0
k -n team-beta edit deploy metrics-collector     # container node-exporter: privileged: false (ou remova o securityContext)
k -n team-beta rollout status deploy metrics-collector
```

Pegadinhas:
- O Pod `bootstrap` só é privilegiado no **initContainer** — `k get pod -o yaml | grep privileged` acha, mas um jsonpath apenas em `.spec.containers` não.
- O `metrics-collector` tem **dois containers**; só o segundo é privilegiado.
- Deletar Pods de um Deployment não resolve: o ReplicaSet recria iguais. Corrija o template.
- `log-agent` tem `SYS_ADMIN` (perigoso, mas **não** é `privileged`); `api` tem `privileged: false` explícito. Não são alvos.
- Cuidado em `kube-system`: CNI (Cilium) e kube-proxy são legitimamente privilegiados.

---

## Q3 (Difícil) — auditoria multi-regra e correção

Visão rápida de tudo (Pod, hostPID, hostNetwork, privileged, runAsUser pod/container):

```bash
for ns in fin-a fin-b fin-c; do
  k -n $ns get pods -o custom-columns='POD:.metadata.name,OWNER:.metadata.ownerReferences[0].name,HOSTPID:.spec.hostPID,HOSTNET:.spec.hostNetwork,PRIV:.spec.containers[*].securityContext.privileged,INITPRIV:.spec.initContainers[*].securityContext.privileged,PODUID:.spec.securityContext.runAsUser,CUID:.spec.containers[*].securityContext.runAsUser'
done
# UID efetivo (o que importa para R4 — a imagem pode definir USER):
for ns in fin-a fin-b fin-c; do for p in $(k -n $ns get pod -o name); do
  for c in $(k -n $ns get $p -o jsonpath='{.spec.containers[*].name}'); do
    echo "$ns/$p/$c uid=$(k -n $ns exec $p -c $c -- id -u)"; done; done; done
```

Resultado da análise:

| Workload | Violação | Detalhe |
|---|---|---|
| fin-a/ledger | R1, R4 | privileged e busybox roda como root |
| fin-a/audit-shipper | R2 | hostPID |
| fin-a/web | — | nginx-unprivileged (UID 101), runAsNonRoot |
| fin-b/cache | R3 | hostNetwork |
| fin-b/batch | R4 | **pegadinha**: Pod tem runAsUser 1000, mas o container define runAsUser 0 (container vence) |
| fin-b/reporter | — | UID 2000, `hostNetwork: false` explícito |
| fin-c/metrics (Pod) | R4 | sem securityContext → root |
| fin-c/sidecar-app | R1 | **pegadinha**: initContainer privilegiado |
| fin-c/api | — | UID 1001 |

```bash
cat > /opt/course/14/q3/violations.txt <<'TXT'
fin-a/ledger
fin-a/audit-shipper
fin-b/cache
fin-b/batch
fin-c/metrics
fin-c/sidecar-app
TXT
```

Correções:

```bash
# ledger: remover privileged e rodar como 1000
k -n fin-a patch deploy ledger --type=json -p='[
 {"op":"remove","path":"/spec/template/spec/containers/0/securityContext/privileged"},
 {"op":"add","path":"/spec/template/spec/securityContext","value":{"runAsUser":1000,"runAsNonRoot":true}}]'

# audit-shipper: remover hostPID
k -n fin-a patch deploy audit-shipper --type=json -p='[{"op":"remove","path":"/spec/template/spec/hostPID"}]'

# cache: remover hostNetwork
k -n fin-b patch deploy cache --type=json -p='[{"op":"remove","path":"/spec/template/spec/hostNetwork"}]'

# batch: remover o runAsUser 0 do container (passa a valer o 1000 do Pod)
k -n fin-b patch deploy batch --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/securityContext/runAsUser"}]'

# sidecar-app: initContainer sem privileged
k -n fin-c patch deploy sidecar-app --type=json -p='[{"op":"remove","path":"/spec/template/spec/initContainers/0/securityContext/privileged"}]'

# metrics (Pod avulso): Pods são praticamente imutáveis -> exportar, editar, recriar
k -n fin-c get pod metrics -o yaml > /tmp/metrics.yaml
# edite: adicione spec.securityContext: {runAsUser: 1000, runAsNonRoot: true}
k replace --force -f /tmp/metrics.yaml
```

(Pode usar `k edit` em todos, se preferir; `k edit` de Pod salva em `/tmp/kubectl-edit-*.yaml` quando a alteração é proibida → `k replace --force -f` nele.)

Validação:
```bash
for ns in fin-a fin-b fin-c; do k -n $ns get deploy; done
k -n fin-b exec deploy/batch -- id -u     # 1000
```

Pegadinhas:
- `runAsNonRoot: true` sozinho **não muda** o usuário: só impede a execução se o UID for 0 (o Pod fica em `CreateContainerConfigError`). Defina `runAsUser`.
- Remover `hostNetwork` pode quebrar apps que escutam em portas do nó — avalie, mas a regra manda.
- Spec de Pod não permite alterar securityContext em runtime: sempre recrie (`replace --force`).

Docs:
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
