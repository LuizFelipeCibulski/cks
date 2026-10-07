# Soluções — Runtime Sandbox (gVisor / RuntimeClass)

> Conceitos-chave
> - Containers comuns (runc) compartilham o **kernel do host**: um exploit de kernel dentro do container afeta o nó. **Sandboxes** colocam uma camada extra: o **gVisor** (`runsc`) implementa um "kernel de aplicação" em user space (Sentry) que intercepta as syscalls; Kata Containers usa micro-VMs.
> - O kubelet fala com o containerd via CRI; o containerd escolhe o runtime pelo **handler** (`runtimes.<handler>` no `config.toml`). O shim do gVisor é `containerd-shim-runsc-v1` → `runtime_type = "io.containerd.runsc.v1"`.
> - A **RuntimeClass** (`node.k8s.io/v1`, objeto **sem namespace**) liga um nome usado no Pod (`spec.runtimeClassName`) a um `handler` do CRI. Pode ter `scheduling` (nodeSelector/tolerations, mesclados no Pod pelo admission RuntimeClass) e `overhead`.
> - Prova clássica de que está no gVisor: `dmesg` dentro do container mostra mensagens do gVisor ("Starting gVisor..."); `uname -r` mostra uma versão de kernel "falsa" (4.4.0). Em runc, `dmesg` costuma dar "Operation not permitted".

---

## Q1 (Fácil)

```yaml
# rc.yaml  (copie da doc: kubernetes.io/docs/concepts/containers/runtime-class)
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
```

```bash
k apply -f rc.yaml
k -n sandbox run sandboxed --image=nginx:1.27-alpine --dry-run=client -o yaml > pod.yaml
# adicione em spec:   runtimeClassName: gvisor
k apply -f pod.yaml
k -n sandbox get pod sandboxed -o wide
k -n sandbox exec sandboxed -- dmesg
# [    0.000000] Starting gVisor...
```

Pegadinhas:
- `handler` deve ser **exatamente** o nome configurado no containerd (`runsc`), não o nome da RuntimeClass.
- `runtimeClassName` é campo do **Pod spec** (não do container). Pods são imutáveis aqui: para mudar, recrie (`k replace --force -f`).
- Erro típico com handler errado: Pod em `ContainerCreating` com evento `FailedCreatePodSandBox ... no runtime for "xyz" is configured`.

---

## Q2 (Médio) — escolher a RuntimeClass certa e migrar Deployments

```bash
k get runtimeclass
# NAME             HANDLER
# gvisor           gvisor       <- nome bonito, handler inexistente
# kata             kata-qemu    <- não instalado
# secure-runtime   runsc

# quais handlers o containerd conhece? (no nó)
crictl info | grep -A3 -i runsc            # ou: grep -n runtimes /etc/containerd/config.toml
# ssh node01 'crictl info | grep -i runsc'
echo secure-runtime > /opt/course/16/q2/runtimeclass.txt
```

Migrar todos os Deployments do namespace (patch no template → rollout):

```bash
for d in $(k -n untrusted get deploy -o name); do
  k -n untrusted patch $d -p '{"spec":{"template":{"spec":{"runtimeClassName":"secure-runtime"}}}}'
done
k -n untrusted rollout status deploy scanner
k -n untrusted get pod -o custom-columns=NAME:.metadata.name,RC:.spec.runtimeClassName,STATUS:.status.phase

k -n untrusted exec deploy/scanner -- dmesg > /opt/course/16/q2/dmesg.txt
cat /opt/course/16/q2/dmesg.txt
```

Pegadinhas:
- Se você testar a RuntimeClass `gvisor`, os Pods ficam travados com `no runtime for "gvisor" is configured` — leia os eventos (`k describe pod`).
- Não esqueça Deployments "escondidos": liste **todos** (`k -n untrusted get deploy`) — aqui há 3.
- `dmesg` precisa ser rodado **dentro** do Pod (`kubectl exec`), não no nó.
- Não altere o namespace `trusted`.

---

## Q3 (Difícil) — configurar o containerd no nó, RuntimeClass com scheduling e migração

### 1) Registrar o handler no containerd do node01 (sem sobrescrever o config)

```bash
ssh node01
ls -l /usr/local/bin/runsc /usr/local/bin/containerd-shim-runsc-v1
containerd --version                      # 1.7.x -> config "version = 2" | 2.x -> "version = 3"
head -5 /etc/containerd/config.toml       # confira a linha "version = N"
cp /etc/containerd/config.toml /root/config.toml.bak
grep -n 'runtimes' /etc/containerd/config.toml     # veja como o runc está declarado e copie o "caminho"
```

Acrescente **no fim** do arquivo (não apague nada) a seção correspondente à versão:

containerd 2.x (`version = 3`):
```toml
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
```

containerd 1.x (`version = 2`):
```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
```

```bash
systemctl restart containerd
systemctl status containerd --no-pager | head -5
crictl info | grep -i runsc             # o handler deve aparecer
journalctl -u containerd -n 30 --no-pager   # se der erro de TOML (tabela duplicada, aspas...)
exit
k get node node01                         # Ready
```

Por que não usar o `config.toml` do tutorial: ele **substitui** o arquivo inteiro e pode apagar `SystemdCgroup = true` (o kubelet do kubeadm usa cgroup driver systemd → containers reiniciando), registries, sandbox image etc. Se a tabela `runtimes.runsc` já existir no arquivo, edite-a em vez de duplicar (TOML não aceita tabela repetida e o containerd não sobe).

### 2) e 3) Label e RuntimeClass com scheduling

```bash
k label node node01 sandbox.cks.io/runtime=gvisor
```

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor-sandbox
handler: runsc
scheduling:
  nodeSelector:
    sandbox.cks.io/runtime: gvisor
  # tolerations: [...]   # necessário se o nó alvo tiver taint (ex.: cluster de 1 nó = controlplane)
```

O admission controller **RuntimeClass** mescla esse `nodeSelector` no Pod na criação → o scheduler só considera nós com gVisor. Se o Pod já tiver um nodeSelector conflitante, a criação é rejeitada.

### 4) Migrar os Deployments e o troubleshooting

```bash
for d in $(k -n payments get deploy -o name); do
  k -n payments patch $d -p '{"spec":{"template":{"spec":{"runtimeClassName":"gvisor-sandbox"}}}}'
done
k -n payments get pod -o wide
```

`reports` não sobe: os Pods aparecem como `NodeAffinity`/`Failed` (ou `ContainerCreating` com `no runtime for "runsc"` no controlplane):

```bash
k -n payments describe pod -l app=reports | tail
k -n payments get deploy reports -o jsonpath='{.spec.template.spec.nodeName}'    # controlplane!
```

O template tem **`nodeName: controlplane`** → o Pod **ignora o scheduler** (vai direto ao kubelet), logo o nodeSelector da RuntimeClass não é respeitado; o kubelet do controlplane rejeita o Pod (não casa com o nodeSelector) — e mesmo que aceitasse, lá não há gVisor. Corrija removendo o `nodeName`:

```bash
k -n payments patch deploy reports --type=json -p='[{"op":"remove","path":"/spec/template/spec/nodeName"}]'
k -n payments rollout status deploy reports
k -n payments delete pod --field-selector=status.phase=Failed      # limpa os Pods rejeitados
```

### 5) Prova

```bash
k -n payments exec deploy/gateway -- dmesg > /opt/course/16/q3/dmesg.txt
k -n payments get pod -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,RC:.spec.runtimeClassName
```

### 6) runc continua ok
```bash
k run t --image=busybox:1.36 --overrides='{"spec":{"nodeName":"node01"}}' -- sleep 30
k exec t -- dmesg      # "Operation not permitted" = runc normal
```

Pegadinhas:
- Seção do plugin errada para a versão do containerd (ex.: `io.containerd.grpc.v1.cri` num `version = 3`) → o containerd 2.x ignora/migra e o handler não aparece; sempre confirme com `crictl info`.
- `runtime_type` errado (`io.containerd.runsc.v2` não existe; o correto é `io.containerd.runsc.v1`).
- Esquecer o restart do containerd.
- Pôr a label em nós sem gVisor → Pods agendados lá falham com `no runtime for "runsc" is configured`.
- `nodeName` fixo no template ignora scheduler, nodeSelector, affinity **e** taints de NoSchedule.

Docs:
- https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling
- https://gvisor.dev/docs/user_guide/containerd/quick_start/
- https://github.com/containerd/containerd/blob/main/docs/cri/config.md
