# Soluções — Supply Chain: Image Footprint

> Conceito: quanto **menor** a imagem, menor a superfície de ataque (menos binários para um atacante usar, menos pacotes com CVEs).
> Checklist de prova para Dockerfile:
> - imagem base **mínima** e com **tag fixa** (ou digest) — nunca `latest`;
> - **multi-stage**: compila num estágio, copia só o artefato para o final;
> - `USER` não-root;
> - juntar `RUN`s (menos camadas, sem cache do apt), `--no-install-recommends`, `rm -rf /var/lib/apt/lists/*`;
> - remover shells/ferramentas desnecessárias;
> - **nunca** colocar segredos em `ENV`, `ARG` ou `RUN echo ...` — tudo isso fica no histórico (`docker history --no-trunc`).

O setup instala o `podman` se não houver Docker e cria o atalho `docker` → `podman`; os comandos abaixo funcionam com ambos.

---

## Q1 (Fácil) — tag fixa + USER

```dockerfile
FROM alpine:3.20.3

RUN adduser -D -g '' appuser

USER appuser

CMD ["sh", "-c", "sleep 1d"]
```

```bash
cd /opt/course/18/q1
docker build -t app-q1:v1 .
docker run -d --name q1 app-q1:v1
docker exec q1 ps aux | tee /opt/course/18/q1/ps.txt
# PID   USER     TIME  COMMAND
#   1   appuser  0:00  sleep 1d
```

### Por quê
- Sem `USER`, o container roda como **root (UID 0)**. Um escape de container ou um volume montado com permissões amplas vira comprometimento total.
- O `USER` precisa vir **depois** do `RUN adduser` (o usuário precisa existir) e antes do `CMD`.
- Tag flutuante (`alpine` = `alpine:latest`) torna o build não reprodutível e pode trazer mudanças inesperadas. Para imutabilidade total use digest: `alpine:3.20.3@sha256:...`.

### Pegadinhas
- `docker run --name q1 ...` falha se já existir um container `q1` (`docker rm -f q1`).
- No Kubernetes o equivalente é `securityContext.runAsUser`/`runAsNonRoot: true` — note que `runAsNonRoot` com `USER appuser` (nome, não número) faz o kubelet recusar o Pod porque não consegue verificar que não é root. Prefira `USER 1000` numérico em imagens que vão para k8s.

Doc: https://docs.docker.com/reference/dockerfile/#user

---

## Q2 (Médio) — hardening de Dockerfile

```dockerfile
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -u 10001 -M -s /usr/sbin/nologin app \
 && rm -f /usr/bin/bash /bin/bash
ENV URL=https://kubernetes.io
USER app
CMD ["sh", "-c", "curl -s --head \"$URL\" -H \"Authorization: Bearer $API_TOKEN\""]
```

```bash
cd /opt/course/18/q2
docker build -t app-q2:v1 .
docker run --rm -e API_TOKEN=xyz app-q2:v1          # token só em runtime
docker history --no-trunc app-q2:v1 | grep -c 2e064aad   # 0
docker run --rm --entrypoint id app-q2:v1           # uid=10001(app)
```

### Por quê
- `RUN apt-get update` em uma camada e `install` em outra: o cache da camada do `update` é reaproveitado e você instala versões **antigas** de pacotes; além disso cada `RUN` cria uma camada que fica para sempre na imagem.
- `rm -rf /var/lib/apt/lists/*` só reduz o tamanho se estiver **no mesmo RUN** que gerou os arquivos (apagar numa camada posterior só "esconde").
- `ENV API_TOKEN=...` fica no config da imagem (`docker inspect`) e `RUN echo $API_TOKEN > arquivo` fica gravado em uma camada **mesmo que você apague depois**. Segredos entram em **runtime** (`-e`, Secret do k8s) ou, se forem necessários no build, via `RUN --mount=type=secret` (BuildKit).
- Remover `bash` (e ferramentas como `vim`, `nc`) dificulta a vida de quem invadir o container. O `sh` do Ubuntu é o `dash` e continua existindo para o `CMD`.
- `ca-certificates`: com `--no-install-recommends`, o `curl` não puxa os certificados raiz e qualquer `https://` falharia — não é checado pelo verify, mas é a pegadinha do mundo real.

### Pegadinhas
- `rm /bin/bash` **depois** do `USER app` falha (sem permissão). Faça como root, antes do `USER`.
- O `CMD` em formato exec (`["sh","-c", ...]`) é necessário para que `$URL`/`$API_TOKEN` sejam expandidos pelo shell.

Doc: https://docs.docker.com/build/building/best-practices/#apt-get

---

## Q3 (Difícil) — Go multi-stage, distroless/scratch, non-root, sem shell

### Investigação
```bash
cd /opt/course/18/q3/app
cat Dockerfile
docker image ls payments                  # v1 ~ 300+ MB
docker history --no-trunc payments:v1 | grep -i token   # credencial vazada no ENV
```

### Dockerfile (opção distroless)
```dockerfile
# ---- estágio de build ----
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
# CGO_ENABLED=0 => binário estático (sem depender da libc musl/glibc do builder)
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/payments .

# ---- estágio final ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/payments /payments
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/payments"]
```

### Dockerfile (opção scratch)
```dockerfile
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /payments .

FROM scratch
COPY --from=build /payments /payments
USER 10001          # em scratch NÃO existe /etc/passwd: use UID numérico
ENTRYPOINT ["/payments"]
```

### Build, execução e provas
```bash
docker build -t payments:v2 .
docker rm -f payments 2>/dev/null
docker run -d --name payments -p 18080:8080 payments:v2

docker image ls payments                                 # v2 ~ 6-8 MB
curl -s localhost:18080/healthz                          # ok
curl -s localhost:18080/whoami                           # uid=65532
docker run --rm --entrypoint sh payments:v2 -c id        # erro: executable file not found -> sem shell
docker inspect -f '{{.Config.User}}' payments:v2         # 65532:65532
docker history --no-trunc payments:v2 | grep ghp_       # nada
```

### Por quê
- **Multi-stage**: o compilador Go, `git`, `bash`, `curl` e o código-fonte ficam no estágio de build e **não** vão para a imagem final. Apenas o binário é copiado.
- `ENV` do estágio de build **não** é herdado pelo estágio final — por isso o `GITHUB_TOKEN` some (e no exemplo ele foi simplesmente removido; se o build precisasse dele, use `RUN --mount=type=secret`).
- **distroless/static** contém só certificados CA, tzdata e `/etc/passwd` com o usuário `nonroot` (65532) — sem shell, sem gerenciador de pacotes. **scratch** é vazio.
- Sem shell, um atacante que consiga RCE na aplicação não tem `sh` para encadear comandos; também não dá para `kubectl exec ... -- sh` (use `kubectl debug` com container efêmero para troubleshooting).

### Pegadinhas
- Compilar **com** CGO (ou em imagem com gcc) gera binário dinâmico linkado na musl: no `scratch`/distroless static ele falha com `exec /payments: no such file or directory`. Use `CGO_ENABLED=0`.
- `USER nonroot` (nome) funciona no distroless (tem `/etc/passwd`), mas no `scratch` só UID numérico.
- Tags `:debug` do distroless incluem busybox (`/busybox/sh`) — não servem quando o requisito é "sem shell".
- `CMD ["payments"]` sem caminho absoluto não funciona em scratch (não há `PATH` útil); use `ENTRYPOINT ["/payments"]`.
- No Kubernetes, complemente com `securityContext: runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`.

Docs:
- https://docs.docker.com/build/building/multi-stage/
- https://github.com/GoogleContainerTools/distroless
