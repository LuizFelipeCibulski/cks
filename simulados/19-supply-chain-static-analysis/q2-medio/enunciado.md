# Static Analysis — Q2 (Médio)

**Domínio:** Supply Chain Security (20%) — *Perform static analysis of user workloads (e.g. Kubernetes resources, Docker files)*
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

## Contexto

Antes de um release, o time de plataforma recebeu, em `/opt/course/19/q2/`, os seguintes arquivos para revisão:

```
deploy-a.yaml   deploy-b.yaml   pod-c.yaml
Dockerfile-1    Dockerfile-2    Dockerfile-3
```

A ferramenta **KubeLinter** (`kube-linter`) está instalada no host.

## Tarefa

1. Analise **manualmente** os 6 arquivos. Grave em `/opt/course/19/q2/insecure-files.txt` o **nome** (somente o nome, ex.: `deploy-x.yaml`) de cada arquivo que contém uma **prática de segurança claramente insegura** — um por linha. Os arquivos sem problemas não devem ser listados.
2. Rode o `kube-linter` **com a configuração padrão** sobre `/opt/course/19/q2/deploy-b.yaml` e grave a saída completa em `/opt/course/19/q2/kube-linter-b.txt`.
3. Corrija o `/opt/course/19/q2/Dockerfile-3`:
   - nenhuma chave privada pode ser copiada para a imagem;
   - o processo final do container **não** pode rodar como `root`.

   Não altere a imagem base nem o comando (`CMD`).

## Documentação permitida

- https://docs.kubelinter.io/
- https://github.com/stackrox/kube-linter
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://docs.docker.com/build/building/best-practices/
- https://docs.docker.com/build/building/secrets/

Quando terminar: `bash verify.sh`
