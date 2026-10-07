# Soluções — Seccomp

> Conceito: seccomp (*secure computing mode*) filtra **syscalls** que um processo pode fazer ao kernel. Como
> containers compartilham o kernel do host, reduzir as syscalls disponíveis reduz muito o impacto de uma
> exploração (ex.: `unshare`, `keyctl`, `ptrace`, `mount`). Por padrão o Kubernetes roda containers como
> **Unconfined** (sem filtro) — a não ser que o kubelet tenha `seccompDefault: true`.

Referência rápida:

```yaml
securityContext:                 # pod ou container (container tem precedência)
  seccompProfile:
    type: RuntimeDefault         # RuntimeDefault | Localhost | Unconfined
    # localhostProfile: profiles/x.json   # só com type: Localhost — caminho RELATIVO a /var/lib/kubelet/seccomp/
```

- Diretório de perfis do kubelet: `/var/lib/kubelet/seccomp/` (o `--root-dir` do kubelet + `/seccomp`).
- Ver se o filtro está ativo: `grep Seccomp /proc/1/status` dentro do container → `0` desligado, `2` filtro ativo.
- Perfis Localhost: `defaultAction` + lista de `syscalls` com `action` (`SCMP_ACT_ALLOW`, `SCMP_ACT_ERRNO`,
  `SCMP_ACT_LOG`, `SCMP_ACT_KILL`...).

---

## Q1 (Fácil) — RuntimeDefault

Campos de securityContext de Pod são **imutáveis**: é preciso recriar.

```bash
kubectl -n seccomp-q1 get pod web -o yaml > web.yaml
kubectl -n seccomp-q1 get pod legacy -o yaml > legacy.yaml
```

`web.yaml` (essencial):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: seccomp-q1
  labels:
    app: web
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault        # era Unconfined
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
```

`legacy.yaml` — **pegadinha**: o container `app` tem `Unconfined` no nível do container, que vence o nível
do pod. Troque/remova ali também:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy
  namespace: seccomp-q1
  labels:
    app: legacy
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault      # era Unconfined (ou remova o bloco e herde do pod)
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
```

```bash
kubectl replace --force -f web.yaml
kubectl replace --force -f legacy.yaml
kubectl -n seccomp-q1 exec legacy -c app -- grep Seccomp /proc/1/status    # Seccomp: 2
kubectl -n seccomp-q1 exec web -- grep Seccomp /proc/1/status              # Seccomp: 2
```

Dica de velocidade: `kubectl replace --force -f` faz delete + create em um passo. Ao reaproveitar o
`-o yaml`, não precisa limpar `status`/`uid` — o `replace --force` aceita.

---

## Q2 (Médio) — perfil Localhost

```bash
mkdir -p /var/lib/kubelet/seccomp/profiles
cp /opt/course/12/q2/block-chmod.json /var/lib/kubelet/seccomp/profiles/
```

```yaml
# /opt/course/12/q2/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened
  namespace: seccomp-q2
spec:
  nodeSelector:
    kubernetes.io/hostname: controlplane
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/block-chmod.json
```

```bash
kubectl apply -f /opt/course/12/q2/pod.yaml
kubectl -n seccomp-q2 exec hardened -- sh -c 'touch /tmp/secret && chmod 600 /tmp/secret' 2> /opt/course/12/q2/chmod.txt
cat /opt/course/12/q2/chmod.txt     # chmod: /tmp/secret: Operation not permitted
kubectl -n seccomp-q2 exec hardened -- grep Seccomp /proc/1/status
# Seccomp:	2
echo 2 > /opt/course/12/q2/seccomp-mode.txt
```

Por que `Operation not permitted`: `SCMP_ACT_ERRNO` faz a syscall retornar `EPERM` em vez de executar.
Com `SCMP_ACT_KILL` o processo morreria.

Pegadinhas:

- `localhostProfile` é **relativo** a `/var/lib/kubelet/seccomp/`. Escrever `/var/lib/kubelet/seccomp/profiles/...`
  (absoluto) ou só `block-chmod.json` faz o container falhar com `CreateContainerError` / `cannot load seccomp profile`.
- O arquivo precisa existir **no nó onde o pod roda** — o kubelet não copia perfis entre nós.
- O perfil é lido na criação do container: alterou o JSON? Recrie o pod.
- `Seccomp: 2` = modo filtro; `1` = strict; `0` = desligado. Use `Seccomp_filters` para ver quantos filtros.

Docs: https://kubernetes.io/docs/tutorials/security/seccomp/ (tem os exemplos `audit.json`,
`violation.json`, `fine-grained.json` e os YAMLs prontos para copiar).

---

## Q3 (Difícil)

### 1. seccompDefault no kubelet do node01

```bash
ssh node01
cp /var/lib/kubelet/config.yaml /root/kubelet-config.bak
vim /var/lib/kubelet/config.yaml
```

```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
...
seccompDefault: true          # campo de primeiro nível do KubeletConfiguration
```

```bash
systemctl restart kubelet
systemctl status kubelet --no-pager | head -5
exit
kubectl get nodes                                         # node01 Ready
kubectl get --raw /api/v1/nodes/node01/proxy/configz | grep -o '"seccompDefault":[a-z]*'
```

(Alternativa equivalente: flag `--seccomp-default` em `/var/lib/kubelet/kubeadm-flags.env`, mas a questão pede o
arquivo de config — e é o caminho recomendado.)

### 2. Corrigir e instalar o perfil

O rascunho tinha `"defaultAction": "SCMP_ACT_ERRNO"` → **toda** syscall não listada falha, inclusive as que o
runtime precisa para iniciar o processo (`execve`, `mmap`...). Por isso "os pods nem sobem"
(`CreateContainerError`/`RunContainerError`). Para uma *denylist*, o padrão deve ser ALLOW:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

```bash
vim /opt/course/12/q3/no-mkdir.json       # troque o defaultAction
ssh node01 mkdir -p /var/lib/kubelet/seccomp/profiles
scp /opt/course/12/q3/no-mkdir.json node01:/var/lib/kubelet/seccomp/profiles/no-mkdir.json
```

### 3. Deployment builder

```bash
kubectl -n seccomp-q3 edit deploy builder
```

```yaml
    spec:
      nodeSelector:
        kubernetes.io/hostname: node01
      containers:
      - name: builder
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        securityContext:
          seccompProfile:
            type: Localhost
            localhostProfile: profiles/no-mkdir.json
```

```bash
kubectl -n seccomp-q3 rollout status deploy builder
kubectl -n seccomp-q3 get pods -o wide
kubectl -n seccomp-q3 exec deploy/builder -- mkdir /tmp/x    # mkdir: can't create directory '/tmp/x': Operation not permitted
kubectl -n seccomp-q3 exec deploy/builder -- touch /tmp/x    # ok
```

### 4. Pod plain

O `seccompDefault` só vale para containers **criados depois** do restart do kubelet. O pod `plain` já existia:

```bash
kubectl -n seccomp-q3 exec plain -- grep Seccomp /proc/1/status    # Seccomp: 0
kubectl -n seccomp-q3 get pod plain -o yaml > plain.yaml
kubectl replace --force -f plain.yaml                                # recria (spec sem seccompProfile)
kubectl -n seccomp-q3 exec plain -- grep Seccomp /proc/1/status    # Seccomp: 2
```

Pegadinhas da Q3:

- `seccompDefault` em `config.yaml` é ignorado até `systemctl restart kubelet`.
- Indentação errada no `config.yaml` derruba o kubelet: veja `journalctl -u kubelet -f`. Sempre faça backup antes.
- Bloquear só `mkdir` não basta: libc moderna usa `mkdirat`. Na dúvida, liste as duas (idem `chmod`/`fchmodat`,
  `open`/`openat`).
- Perfil instalado só no controlplane (onde está o rascunho) → pods no node01 falham com
  `cannot load seccomp profile`.
- Não adicione `seccompProfile` ao `plain` — a questão quer provar que o padrão do kubelet foi aplicado.

Docs:
- https://kubernetes.io/docs/tutorials/security/seccomp/#enable-the-use-of-runtimedefault-as-the-default-seccomp-profile-for-all-workloads
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/ (procure `seccompDefault`)
