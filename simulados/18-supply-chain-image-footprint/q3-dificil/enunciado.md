# Image Footprint — Q3 (Difícil)

**Domínio:** Supply Chain Security (20%) — *Minimize base image footprint*
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane (baixa a imagem do Go, pode levar ~1 min)
```

> Use o comando `docker` (se o host não tinha Docker, `docker` é um atalho para o `podman`).

## Contexto

O serviço `payments` é escrito em Go e o código está em `/opt/course/18/q3/app/` (`main.go`, `go.mod` e `Dockerfile`).
A imagem atual é construída e executada a partir da imagem completa do compilador Go, com shell, ferramentas extras, rodando como `root` e com uma credencial embutida. Ela tem centenas de MB.

O serviço escuta em `:8080` e expõe:
- `GET /healthz` → `ok`
- `GET /whoami` → o UID do processo (`uid=N`)

## Tarefa

Reescreva `/opt/course/18/q3/app/Dockerfile` atendendo **todos** os requisitos:

1. Use **multi-stage build**: um estágio de build com uma imagem do Go de **tag fixa** (não `latest`) e um estágio final mínimo, baseado em **`scratch`** ou em uma imagem **distroless** (`gcr.io/distroless/...`).
2. O binário deve funcionar no estágio final (atenção a como ele é compilado).
3. A imagem final **não pode conter shell** (`sh`, `bash`, `ash`...).
4. A imagem final deve rodar como **usuário não-root** definido na própria imagem (o `/whoami` não pode retornar `uid=0`).
5. Nenhuma credencial pode existir na imagem final (nem em ENV, nem no histórico).
6. A imagem final deve ter **menos de 20 MB**.
7. Construa a imagem com a tag **`payments:v2`** e rode um container chamado **`payments`** em background, publicando a porta `8080` do container na porta **`18080`** do host.

## Documentação permitida

- https://docs.docker.com/build/building/multi-stage/
- https://docs.docker.com/build/building/best-practices/
- https://github.com/GoogleContainerTools/distroless
- https://docs.docker.com/reference/dockerfile/#user

Quando terminar: `bash verify.sh`
