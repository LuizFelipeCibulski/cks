# Image Footprint — Q1 (Fácil)

**Domínio:** Supply Chain Security (20%) — *Minimize base image footprint*
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

> O setup garante que exista um engine de containers. Use o comando `docker` (se o host não tinha Docker, `docker` é um atalho para o `podman`).

## Contexto

Em `/opt/course/18/q1/Dockerfile` existe o Dockerfile de uma imagem base usada por vários times. Hoje ela usa uma tag flutuante e seus processos rodam como `root`, mesmo já existindo um usuário sem privilégios criado na imagem.

## Tarefa

1. Altere o Dockerfile para usar a imagem base **`alpine:3.20.3`** (tag fixa).
2. Faça com que os processos do container rodem como o usuário **`appuser`** (já criado no Dockerfile).
3. Construa a imagem com a tag **`app-q1:v1`** a partir de `/opt/course/18/q1`.
4. Rode um container chamado **`q1`** dessa imagem em background (comando padrão da imagem) e grave em `/opt/course/18/q1/ps.txt` a saída de `ps aux` executado **dentro** desse container.

## Documentação permitida

- https://docs.docker.com/reference/dockerfile/#user
- https://docs.docker.com/build/building/best-practices/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

Quando terminar: `bash verify.sh`
