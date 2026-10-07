# Static Analysis — Q3 (Difícil)

**Domínio:** Supply Chain Security (20%) — *Perform static analysis of user workloads (e.g. Kubernetes resources, Docker files)*
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

## Contexto

O serviço `catalog` roda no namespace `static-app` e é implantado a partir de `/opt/course/19/q3/deploy.yaml` (Deployment + Service). O pipeline de CI passará a bloquear qualquer manifesto que não passe em duas ferramentas de análise estática, ambas já instaladas no host: **kubesec** e **KubeLinter**.

## Tarefa

Corrija `/opt/course/19/q3/deploy.yaml` (você pode adicionar novos objetos ao mesmo arquivo) para que:

1. `kube-linter lint /opt/course/19/q3/deploy.yaml` (configuração padrão) **não reporte nenhum erro**.
2. `kubesec scan /opt/course/19/q3/deploy.yaml` não reporte **nenhum item crítico** para o Deployment e o **score do Deployment seja >= 10**.
3. A imagem do container passe a ser **`nginxinc/nginx-unprivileged:1.27-alpine`** (escuta na porta **8080**). O Deployment deve continuar com **2 réplicas**.
4. O valor da variável `API_SECRET` não fique em texto puro no Deployment: ele deve vir da chave `api-secret` de um Secret chamado **`catalog-api`** no namespace `static-app`.
5. Aplique o arquivo. O Deployment `catalog` deve ficar com **2/2 réplicas prontas** e o Service `catalog` (porta 80) deve continuar respondendo HTTP dentro do cluster.
6. Salve a saída final do kubesec (JSON) para o arquivo corrigido em `/opt/course/19/q3/kubesec-final.json`.

## Documentação permitida

- https://docs.kubelinter.io/#/generated/checks
- https://kubesec.io/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/configuration/secret/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity

Quando terminar: `bash verify.sh`
