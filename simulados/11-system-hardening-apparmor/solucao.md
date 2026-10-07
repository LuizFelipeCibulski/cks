# Soluções — AppArmor

> Conceito: AppArmor é um LSM (Linux Security Module) de **controle de acesso mandatório** baseado em
> perfis por programa: mesmo como root dentro do container, o processo só acessa os arquivos, capabilities
> e recursos de rede que o perfil permitir. O kubelet não distribui perfis — **o perfil precisa estar carregado
> no kernel do nó onde o pod roda**; o pod só referencia o nome.

Comandos essenciais (no nó):

| Ação | Comando |
|---|---|
| Ver perfis carregados e modo | `aa-status` (ou `cat /sys/kernel/security/apparmor/profiles`) |
| Carregar/recarregar em enforce | `apparmor_parser -r /caminho/perfil` (`-r` = replace; sem `-C` → enforce) |
| Carregar em complain | `apparmor_parser -C -r /caminho/perfil` (ou `aa-complain`, se apparmor-utils existir) |
| Remover do kernel | `apparmor_parser -R /caminho/perfil` |
| Persistir após reboot | copiar para `/etc/apparmor.d/` (o `apparmor.service` carrega tudo de lá no boot) |

Campo no Pod (GA desde 1.30 — as annotations `container.apparmor.security.beta.kubernetes.io/*` estão deprecadas):

```yaml
securityContext:              # no nível do pod OU do container (container tem precedência)
  appArmorProfile:
    type: Localhost           # Localhost | RuntimeDefault | Unconfined
    localhostProfile: <NOME DO PERFIL>   # nome declarado em "profile <nome> {", NÃO o nome do arquivo
```

---

## Q1 (Fácil)

```bash
apparmor_parser -r /opt/course/11/q1/k8s-deny-write   # carrega em enforce
aa-status | grep k8s-deny-write                       # aparece na seção "profiles are in enforce mode"
```

```yaml
# /opt/course/11/q1/pod.yaml (editado)
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: apparmor-q1
spec:
  nodeName: controlplane
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo iniciado; sleep 1d"]
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-deny-write
```

```bash
kubectl apply -f /opt/course/11/q1/pod.yaml
kubectl -n apparmor-q1 exec writer -- cat /proc/1/attr/current   # k8s-deny-write (enforce)
kubectl -n apparmor-q1 exec writer -- touch /tmp/x               # touch: /tmp/x: Permission denied
```

Pegadinhas:

- Se o perfil não estiver carregado no nó, o pod fica em `CreateContainerError`/`Blocked` com
  `apparmor profile not found`. Carregue o perfil e recrie o pod.
- `securityContext` de pod ou de container funcionam; o campo é `appArmorProfile` (camelCase, "A" maiúsculo).
- Dica de velocidade: o tutorial *Restrict a Container's Access to Resources with AppArmor* tem exatamente
  este perfil e o YAML do pod — copie de lá.

Docs: https://kubernetes.io/docs/tutorials/security/apparmor/

---

## Q2 (Médio)

```bash
aa-status | sed -n '/enforce mode/,/complain mode/p'   # k8s-legacy-audit em enforce
aa-status | grep -A3 'complain mode'                    # k8s-nginx-ro está em complain

# 1. complain → enforce (sem editar o arquivo)
apparmor_parser -r /etc/apparmor.d/k8s-nginx-ro         # ou: aa-enforce /etc/apparmor.d/k8s-nginx-ro
grep k8s- /sys/kernel/security/apparmor/profiles
# k8s-nginx-ro (enforce)
# k8s-legacy-audit (enforce)

# 2. lista dos k8s-* em enforce
sed -n 's/^\(k8s-[^ ]*\) (enforce)$/\1/p' /sys/kernel/security/apparmor/profiles > /opt/course/11/q2/enforced.txt
cat /opt/course/11/q2/enforced.txt
```

> Atenção: se você fez a Q1 antes, `k8s-deny-write` também estará carregado e deve entrar na lista — a pergunta
> é sobre *todos* os perfis `k8s-*` em enforce no momento.

```bash
# 3. Deployment
kubectl -n apparmor-q2 edit deploy web
```

```yaml
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        securityContext:
          appArmorProfile:
            type: Localhost
            localhostProfile: k8s-nginx-ro
      - name: logger
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date; sleep 10; done"]
        securityContext:
          appArmorProfile:
            type: RuntimeDefault
```

```bash
kubectl -n apparmor-q2 rollout status deploy web
kubectl -n apparmor-q2 exec deploy/web -c nginx  -- cat /proc/1/attr/current   # k8s-nginx-ro (enforce)
kubectl -n apparmor-q2 exec deploy/web -c logger -- cat /proc/1/attr/current   # cri-containerd.apparmor.d (enforce)
kubectl -n apparmor-q2 exec deploy/web -c nginx -- sh -c 'echo x > /usr/share/nginx/html/index.html'
# sh: can't create /usr/share/nginx/html/index.html: Permission denied
```

Por quê: em *complain* o AppArmor só **registra** violações (no `dmesg`/`journalctl -k`), não bloqueia —
útil para desenvolver perfis, inútil para proteger. `RuntimeDefault` é o perfil padrão do containerd
(`cri-containerd.apparmor.d`), que nega coisas como escrita em `/proc/sys` e `mount`.

Pegadinhas:

- Colocar o perfil no nível do **pod** aplicaria o `k8s-nginx-ro` também ao `logger`. Use nível de container
  (ou pod = RuntimeDefault + override no nginx).
- Editar o arquivo e adicionar `flags=(complain)`/removê-lo não era pedido — o modo vem de como o perfil foi
  carregado (`-C`).
- Mudanças em perfil só valem para containers **novos**; o rollout do Deployment recria os pods.

---

## Q3 (Difícil)

### Diagnóstico

```bash
kubectl -n apparmor-q3 get pods -o wide
kubectl -n apparmor-q3 describe pod <pod> | tail
# Error: failed to create containerd container: apparmor profile not found k8s-deny-uploads
grep '^profile' /opt/course/11/q3/k8s-deny-uploads
# profile k8s-deny-upload flags=(...)     ← o nome do PERFIL é k8s-deny-upload (sem "s")
```

Três problemas: perfil não carregado em nenhum nó, nome do perfil ≠ nome do arquivo, e pods sem restrição de
nó (cairiam em nós sem o perfil).

### 1. Label

```bash
kubectl label node node01 security=apparmor
```

### 2. Instalar o perfil no node01 (persistente)

```bash
scp /opt/course/11/q3/k8s-deny-uploads node01:/etc/apparmor.d/k8s-deny-uploads
ssh node01
apparmor_parser -r /etc/apparmor.d/k8s-deny-uploads
aa-status | grep k8s-deny-upload        # k8s-deny-upload em enforce
exit
```

Carregar a partir de `/etc/apparmor.d/` garante que o `apparmor.service` o recarregue no boot.

### 3. Deployment

```bash
kubectl -n apparmor-q3 edit deploy uploader
```

```yaml
    spec:
      nodeSelector:
        security: apparmor
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: k8s-deny-upload      # nome do perfil, não do arquivo
      containers:
      - name: uploader
        ...
```

(A toleration existente não atrapalha: toleration só *permite* agendar no controlplane; quem *restringe* é o
nodeSelector.)

```bash
kubectl -n apparmor-q3 rollout status deploy uploader
kubectl -n apparmor-q3 get pods -o wide          # 2/2 Running em node01
```

### 4. Prova

```bash
kubectl -n apparmor-q3 exec deploy/uploader -- touch /uploads/test 2> /opt/course/11/q3/write-test.txt
cat /opt/course/11/q3/write-test.txt
# touch: /uploads/test: Permission denied
# command terminated with exit code 1
kubectl -n apparmor-q3 exec deploy/uploader -- touch /tmp/ok && echo tmp-ok
```

Pegadinhas da Q3:

- `localhostProfile` usa o **nome declarado** no perfil (`profile NOME {`), conferível em `aa-status`.
  Usar o nome do arquivo é o erro mais comum (killer.sh cobra isso).
- Carregar o perfil só no `controlplane` (onde o arquivo está) não adianta: o pod roda no `node01`.
- `apparmor_parser` sem copiar para `/etc/apparmor.d/` funciona até o próximo reboot — o item pede persistência.
- Redirecione o **stderr** (`2>`) para capturar a mensagem de erro; `>` sozinho grava um arquivo vazio.
- Pods antigos em `CreateContainerError` às vezes ficam presos: `kubectl -n apparmor-q3 delete pod --all`
  ou `kubectl rollout restart`.

Validação manual: `ssh node01 aa-status`, `kubectl get nodes -l security=apparmor`,
`kubectl -n apparmor-q3 exec deploy/uploader -- cat /proc/1/attr/current`.

Docs:
- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/
