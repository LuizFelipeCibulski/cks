# Behavioral Analytics (Falco + strace) — Soluções

---

## Q1 (Fácil) — strace para achar o processo que lê /etc/shadow

### Por quê
Todo acesso a arquivo passa por syscalls (`openat`, `read`...). `strace` usa `ptrace` para interceptar as syscalls de um processo em execução — é a forma mais direta de ver o que um binário "caixa-preta" está fazendo. O Falco faz a mesma coisa em escala (via eBPF), com regras.

### Passo a passo

```bash
ps aux | grep -E 'cache-warmer|log-shipper|metrics-agent' | grep -v grep
# ou
pgrep -a cache-warmer; pgrep -a log-shipper; pgrep -a metrics-agent
```

Observe cada um por alguns segundos (os loops rodam a cada 2s):

```bash
strace -p $(pgrep -xo log-shipper) -e trace=openat,open 2>&1 | head
# openat(AT_FDCWD, "/etc/os-release", O_RDONLY) = 3
# openat(AT_FDCWD, "/etc/shadow", O_RDONLY) = 3      <-- aqui
```

Dicas de `strace`:
- `-p PID` anexa a um processo existente; `-f` segue filhos (forks/threads).
- `-e trace=openat` ou `-e trace=%file` filtra só syscalls de arquivo.
- `-c` (ou `-cw`) mostra um resumo/contagem de syscalls ao final (Ctrl+C).
- `strace -p PID 2>&1 | grep shadow` é suficiente na prova.

Gravar as respostas e remediar:

```bash
PID=$(pgrep -xo log-shipper)
mkdir -p /opt/course/22/q1
echo log-shipper > /opt/course/22/q1/name.txt
echo $PID        > /opt/course/22/q1/pid.txt
echo openat      > /opt/course/22/q1/syscall.txt
ls -l /proc/$PID/exe          # /usr/local/bin/log-shipper
kill -9 $PID
rm -f /usr/local/bin/log-shipper
```

### Pegadinhas
- Grave o PID **antes** de matar o processo.
- Use o caminho de `/proc/<pid>/exe` para saber qual binário remover (o nome do processo pode ser enganoso).
- `cat /proc/<pid>/fd/0` também revelaria o script aqui — na prova, o método esperado costuma ser `strace`.

Docs: https://man7.org/linux/man-pages/man1/strace.1.html

---

## Q2 (Médio) — Falco: identificar e neutralizar workloads

### Por quê
O Falco monitora syscalls no kernel (driver modern eBPF) e compara com regras. Com o plugin de containers, cada alerta traz `container_id`, `k8s_ns_name` e `k8s_pod_name` — o elo entre o evento no kernel e o objeto Kubernetes. Escalar para 0 contém a ameaça sem perder o objeto (preserva evidências/forense da spec).

### Passo a passo

```bash
systemctl list-units | grep falco        # descobre o nome do serviço (ex.: falco-modern-bpf)
journalctl -u falco-modern-bpf --since "-5min" -o cat | grep -E 'k8s_ns_name=(shop|billing|analytics)'
# alternativa: grep falco /var/log/syslog
```

Saída típica (resumida):

```
Warning Sensitive file opened for reading by non-trusted program | file=/etc/shadow ... process=cat ... k8s_pod_name=invoice-xxxx k8s_ns_name=billing
Critical Executing binary not part of base image | ... proc_exepath=/tmp/xmrig ... k8s_pod_name=collector-xxxx k8s_ns_name=analytics
Warning Grep private keys or passwords activities found | ... command=find /root /home -name id_rsa ... k8s_ns_name=analytics
```

Se a sua versão do Falco não mostrar `k8s_*`, use o `container_id`:

```bash
crictl ps --id <container_id>     # mostra o POD ID e nome do container
crictl inspect <container_id> | grep -E 'io.kubernetes.pod.(name|namespace)'
```

Pod → Deployment: o nome `invoice-<rs-hash>-<pod-hash>` indica o Deployment `invoice` (confirme com `k -n billing get pod <pod> -o jsonpath='{.metadata.ownerReferences}'` e o ReplicaSet).

```bash
k -n billing   scale deploy invoice   --replicas=0
k -n analytics scale deploy collector --replicas=0
mkdir -p /opt/course/22/q2
printf "billing/invoice\nanalytics/collector\n" > /opt/course/22/q2/report.txt
```

### Pegadinhas
- Apagar o Pod não resolve: o ReplicaSet recria. É o Deployment que precisa ir a 0.
- Não escale Deployments "inocentes" só porque estão no mesmo namespace.
- Regras de prioridade diferentes (Warning, Critical) — leia todas, não só um tipo.

Docs: https://falco.org/docs/reference/rules/default-rules/

---

## Q3 (Difícil) — Regra custom, coleta de alertas e investigação no host

### Por quê
Regras locais (`falco_rules.local.yaml`) são o lugar certo para customizações: sobrevivem a upgrades do pacote, que sobrescrevem `falco_rules.yaml`. Um erro de sintaxe/campo faz o Falco **não iniciar** — é preciso olhar o journal.

### 1. Diagnóstico

```bash
systemctl status falco-modern-bpf
journalctl -u falco-modern-bpf -n 50 --no-pager
# ... LOAD_ERR_COMPILE_CONDITION ... filter_check called with nonexistent field fd.nam
```

### 2. Corrigir a regra

```yaml
# /etc/falco/falco_rules.local.yaml
- rule: Write below etc in container
  desc: Detecta escrita em arquivos abaixo de /etc dentro de containers
  condition: open_write and container and fd.name startswith /etc/
  output: "%evt.time,%container.id,%container.image.repository,%user.uid,%proc.name"
  priority: WARNING
  tags: [filesystem, container, cks]
```

- `open_write` e `container` são macros definidas em `falco_rules.yaml` (carregado antes do local).
- Validar antes de reiniciar: `falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml` (ou só `falco --dry-run` em versões recentes).

```bash
systemctl restart falco-modern-bpf
systemctl is-active falco-modern-bpf
```

> Versões recentes do Falco acrescentam campos extras ao final do output (`container_id=... k8s_pod_name=...`, via `append_output`). Isso é esperado — o início da mensagem é o formato que você definiu.

### 3. Coletar por 30+ segundos

```bash
mkdir -p /opt/course/22/q3
timeout 40 journalctl -u falco-modern-bpf -f -n0 -o cat > /opt/course/22/q3/falco.log
grep -c , /opt/course/22/q3/falco.log
```

Alternativas: `sleep 40; journalctl -u falco-modern-bpf --since "-40s" -o cat | grep ',.*,.*,' > ...` ou parar o serviço e rodar `falco -U -M 40 > arquivo` (depois reinicie o serviço!).

### 4. Container ID → Pod

```bash
grep -o ',[0-9a-f]\{12\},' /opt/course/22/q3/falco.log | sort | uniq -c   # container mais frequente
crictl ps --id <cid>
crictl inspect <cid> | grep -E '"io.kubernetes.pod.(name|namespace)"'
# ou crictl pods --id <podid>
echo "finance/ledger-worker" > /opt/course/22/q3/pod.txt
```

### 5. PID no host e /proc/<pid>/exe

```bash
PID=$(crictl inspect --output go-template --template '{{.info.pid}}' <cid>)
# ou: crictl inspect <cid> | grep '"pid"'
ls -l /proc/$PID/exe
# /proc/1234/exe -> /tmp/.cache/busybox
cat /proc/$PID/cmdline | tr '\0' ' '
echo /tmp/.cache/busybox > /opt/course/22/q3/exe.txt
```

O processo principal não é o `/bin/sh` da imagem: o container copiou o busybox para `/tmp/.cache/` (camada gravável) e fez `exec` — típico de "drift" pós-comprometimento. O caminho visto em `/proc/<pid>/exe` é relativo ao mount namespace do container. No host, o arquivo fica sob o rootfs do container (`/run/containerd/io.containerd.runtime.v2.task/k8s.io/<id>/rootfs/...`).

### 6. Remover o Pod

```bash
k -n finance delete pod ledger-worker --force --grace-period=0
```

### Pegadinhas
- Esquecer de reiniciar o Falco após editar a regra (ou editar `falco_rules.yaml` em vez do `.local`).
- `fd.name startswith /etc` também casaria `/etcd-data` — use `/etc/`.
- `%container.id` no output é o ID **curto** (12 chars); `crictl` aceita prefixo.
- Coletar antes de apagar o Pod — depois não haverá mais alertas.

Docs: https://falco.org/docs/concepts/rules/basic-elements/ · https://falco.org/docs/reference/rules/supported-fields/
