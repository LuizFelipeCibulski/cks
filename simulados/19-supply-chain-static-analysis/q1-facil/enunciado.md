# Static Analysis — Q1 (Fácil)

**Domínio:** Supply Chain Security (20%) — *Perform static analysis of user workloads (e.g. Kubernetes resources, Docker files)*
**Tempo sugerido:** ~4 minutos

## Preparação

```bash
bash setup.sh   # como root, no controlplane
```

## Contexto

O manifesto `/opt/course/19/q1/pod.yaml` descreve o Pod `legacy-agent` do namespace `kubesec-lab`. Antes de aprovar o deploy, o time de segurança exige uma análise com o **kubesec** (já instalado no host).

## Tarefa

1. Faça o scan de `/opt/course/19/q1/pod.yaml` com o kubesec e salve o resultado (JSON) em `/opt/course/19/q1/kubesec-before.json`.
2. Grave em `/opt/course/19/q1/critical.txt` os **IDs** de todos os itens classificados como **critical** pelo kubesec, um por linha.
3. Corrija `/opt/course/19/q1/pod.yaml` para que o kubesec **não reporte nenhum item crítico** e o **score seja maior ou igual a 4**. Mantenha nome, namespace, imagem e comando do container.
4. Crie o Pod a partir do arquivo corrigido. Ele deve ficar `Running`.

## Documentação permitida

- https://kubesec.io/
- https://github.com/controlplaneio/kubesec
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

Quando terminar: `bash verify.sh`
