# Soluções — 05 Verify Platform Binaries

> Conceito central: **cadeia de suprimentos dos binários da plataforma**. Um binário do
> control plane ou do kubelet adulterado dá ao atacante controle total do cluster. O projeto
> Kubernetes publica, em `dl.k8s.io`, os binários e os arquivos `.sha256` / `.sha512` de cada
> um, além dos tarballs (`kubernetes-server-linux-amd64.tar.gz` etc.) listados no CHANGELOG.
> Na prova você compara hashes com `sha256sum`/`sha512sum` — basta que **1 byte** seja diferente
> para o hash mudar completamente.

---

## Q1 (Fácil) — hashes fornecidos

```bash
cd /opt/course/5/q1
cat sha512sums.txt                # formato "<hash>  <arquivo>" (dois espaços)

# forma mais rápida: o próprio sha512sum compara
sha512sum -c sha512sums.txt
# kubectl: OK
# kubeadm: FAILED     <- exemplo
# kubelet: OK

echo kubeadm > /opt/course/5/q1/adulterado.txt    # use o nome que deu FAILED
rm /opt/course/5/q1/kubeadm
```

Alternativa manual (quando o enunciado dá só o hash em texto):

```bash
sha512sum kubeadm
grep kubeadm sha512sums.txt
# ou comparar automaticamente:
echo "<hash-oficial>  kubeadm" | sha512sum -c
```

**Pegadinhas**
- O formato do arquivo para `-c` precisa ter **dois espaços** entre hash e nome.
- O tamanho do arquivo é igual nos dois casos — não dá para confiar em `ls -l`.
- Leia se pedem SHA256 ou SHA512: são hashes diferentes, comparar o errado nunca bate.
- Grave **só o nome** no arquivo de resposta (sem caminho, se o enunciado pedir assim).

**Validação:** `sha512sum -c sha512sums.txt` deve mostrar só `OK` para os que restaram
(o removido aparece como "No such file").

Doc: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux

---

## Q2 (Médio) — descobrir a versão e buscar os hashes oficiais

### 1. Versão do cluster

```bash
kubectl get nodes          # coluna VERSION, ex: v1.34.1
kubelet --version          # Kubernetes v1.34.1
echo v1.34.1 > /opt/course/5/q2/versao.txt
```

### 2. Checksums oficiais em dl.k8s.io

O padrão da URL (está na página "Install kubectl" da doc) é:
`https://dl.k8s.io/release/<versão>/bin/linux/amd64/<binário>.sha256`

```bash
V=$(kubelet --version | awk '{print $2}')
ARCH=amd64                 # ou: dpkg --print-architecture
cd /opt/course/5/q2
for b in kubectl kubeadm kubelet kube-proxy; do
  echo "$(curl -sL https://dl.k8s.io/release/$V/bin/linux/$ARCH/$b.sha256)  $b" | sha256sum -c
done
# kubectl: OK
# kubeadm: FAILED
# kubelet: FAILED
# kube-proxy: OK
```

> O arquivo `.sha256` contém **apenas o hash**, sem o nome — por isso montamos a linha
> `"<hash>  <nome>"` antes de passar para `sha256sum -c`.

### 3 e 4. Resposta e quarentena

```bash
printf 'kubeadm\nkubelet\n' > /opt/course/5/q2/adulterados.txt
mkdir -p /opt/course/5/q2/quarentena
mv kubeadm kubelet /opt/course/5/q2/quarentena/
```

**Pegadinhas**
- Um dos binários adulterados **não tem bytes alterados**: é outro binário oficial com o nome
  trocado (ex: um `kubectl` renomeado para `kubelet`). Ele é "oficial", mas não é o que diz ser
  — o hash denuncia. Por isso compare **sempre** pelo nome/versão esperados.
- Versão errada = todos os hashes falham. Se tudo deu `FAILED`, desconfie da versão/arquitetura
  (`amd64` x `arm64`) e não do binário.
- `curl` sem `-L` pode retornar o HTML de redirecionamento em vez do hash.

Docs: https://kubernetes.io/releases/download/#binaries

---

## Q3 (Difícil) — binários em uso x tarball oficial de servidor

### 1. Descobrir as versões de cada componente

```bash
kubectl version                     # Client Version (kubectl) e Server Version (apiserver)
kubelet --version                   # versão do kubelet
```

Normalmente são todas iguais. Se forem diferentes, você precisa do tarball de **cada** versão.

### 2. Baixar o tarball oficial de servidor

O link está no CHANGELOG da versão (seção "Server Binaries"), padrão:

```bash
V=v1.34.1        # versão do componente
mkdir -p /root/k8s-$V && cd /root/k8s-$V
curl -LO https://dl.k8s.io/$V/kubernetes-server-linux-amd64.tar.gz
# opcional: conferir o próprio tarball com o sha512 publicado no CHANGELOG
sha512sum kubernetes-server-linux-amd64.tar.gz

# extraia só o necessário (o tarball é grande)
tar xzf kubernetes-server-linux-amd64.tar.gz \
  kubernetes/server/bin/kube-apiserver kubernetes/server/bin/kubelet kubernetes/server/bin/kubectl
ls kubernetes/server/bin/
```

### 3. Localizar os binários **em uso**

**kube-apiserver (dentro do container):** a imagem é distroless — não há `sh` nem
`sha512sum` dentro dela, então `kubectl exec` não ajuda. Acesse o filesystem do container pelo
`/proc` do host:

```bash
crictl ps | grep kube-apiserver                  # confirma o container
PID=$(pgrep -xo kube-apiserver)                   # ou: crictl inspect <id> | grep -i '"pid"'
ls -l /proc/$PID/root/usr/local/bin/              # binário fica em /usr/local/bin na imagem
sha512sum /proc/$PID/root/usr/local/bin/kube-apiserver
sha512sum kubernetes/server/bin/kube-apiserver
```

Alternativa: `find /proc/$PID/root/ -name kube-apiserver` ou
`ls -l /proc/$PID/exe` (o link `exe` também aponta para o binário em execução —
`sha512sum /proc/$PID/exe` funciona).

**kubelet (host):**

```bash
systemctl cat kubelet | grep ExecStart          # /usr/bin/kubelet
ls -l /proc/$(pgrep -xo kubelet)/exe
sha512sum /usr/bin/kubelet kubernetes/server/bin/kubelet
```

**kubectl (o que roda no shell):** a pegadinha principal! Não presuma `/usr/bin/kubectl`.

```bash
type -a kubectl          # lista TODOS na ordem do PATH (e alias k)
which kubectl
readlink -f $(which kubectl)
sha512sum $(readlink -f $(which kubectl)) kubernetes/server/bin/kubectl
```

### 4. Resposta

```bash
mkdir -p /opt/course/5/q3
cat > /opt/course/5/q3/resultado.txt <<'EOF'
kube-apiserver: OK
kubelet: OK
kubectl: ALTERADO
EOF
```

(Use os resultados que **você** obteve; no cenário padrão o kubectl é o adulterado.)

### 5. Substituir o binário adulterado pelo oficial

```bash
KPATH=$(readlink -f $(which kubectl))
install -m 755 kubernetes/server/bin/kubectl "$KPATH"     # ou cp + chmod +x
hash -r                                                     # limpa cache de caminho do bash
sha512sum "$KPATH" kubernetes/server/bin/kubectl            # agora iguais
kubectl get nodes
```

**Por que o kubectl "funcionava" mesmo adulterado?** Bytes anexados ao final de um ELF não
impedem a execução — por isso "funciona normalmente" não prova integridade; só o hash prova.

**Pegadinhas**
- Comparar o binário do **host** (`/usr/bin/...`) quando o enunciado pede o do **container**
  (kube-apiserver roda a partir da imagem `registry.k8s.io/kube-apiserver`, não do host).
- Usar tarball de versão diferente da do componente.
- Se o kubelet estivesse adulterado: substituir o arquivo e `systemctl restart kubelet`.
  Se o kube-apiserver estivesse adulterado, a correção seria trocar a imagem do static pod
  (por uma imagem oficial / com digest correto) — não dá para "copiar" binário para dentro.
- Não saia apagando o tarball sem conferir: ele é grande, extraia só o necessário para não
  perder tempo.

**Validação manual**
```bash
for f in /proc/$(pgrep -xo kube-apiserver)/root/usr/local/bin/kube-apiserver \
         /usr/bin/kubelet $(readlink -f $(which kubectl)); do sha512sum $f; done
sha512sum kubernetes/server/bin/{kube-apiserver,kubelet,kubectl}
```

Docs:
- https://kubernetes.io/releases/download/
- https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG (links e sha512 dos tarballs)
