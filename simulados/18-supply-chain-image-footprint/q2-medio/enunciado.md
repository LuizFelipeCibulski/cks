# Image Footprint — Q2 (Médio)

**Domínio:** Supply Chain Security (20%) — *Minimize base image footprint* / boas práticas de Dockerfile
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

> Use o comando `docker` (se o host não tinha Docker, `docker` é um atalho para o `podman`).

## Contexto

O time de integrações mantém o Dockerfile `/opt/course/18/q2/Dockerfile`. Uma revisão de segurança apontou que a imagem gerada é grande, roda como root, carrega um token de API e contém ferramentas desnecessárias.

O token **não deve mais fazer parte da imagem**: a partir de agora ele será injetado em tempo de execução, via variável de ambiente `API_TOKEN` (ex.: `docker run -e API_TOKEN=... ` ou um Secret no Kubernetes).

## Tarefa

Edite `/opt/course/18/q2/Dockerfile` de forma que:

1. A imagem base seja **`ubuntu:24.04`** (tag fixa).
2. Apenas o `curl` seja instalado (`vim` e `netcat` não são necessários em produção). `apt-get update` e a instalação aconteçam em **uma única instrução `RUN`**, sem pacotes recomendados e sem deixar o cache de listas do apt (`/var/lib/apt/lists`) na imagem.
3. O valor do token **não apareça em lugar nenhum da imagem** (nem em variável de ambiente, nem em arquivo, nem no histórico de camadas).
4. A imagem **não contenha o `bash`**.
5. O container rode como um usuário **`app` com UID `10001`** (crie o usuário no Dockerfile).
6. O comando padrão (`CMD`) continue usando `$URL` e `$API_TOKEN` em tempo de execução.

Construa a imagem com a tag **`app-q2:v1`** a partir de `/opt/course/18/q2`.

## Documentação permitida

- https://docs.docker.com/build/building/best-practices/
- https://docs.docker.com/reference/dockerfile/
- https://docs.docker.com/build/building/secrets/

Quando terminar: `bash verify.sh`
