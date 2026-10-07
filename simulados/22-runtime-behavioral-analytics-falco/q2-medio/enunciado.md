# Behavioral Analytics — Q2 (Médio)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Detect threats within physical infrastructure, apps, networks, data, users and workloads
**Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (instala o Falco se necessário, ~2 min)
```

## Contexto

O Falco está instalado como serviço systemd no `controlplane` e usa as regras padrão. Há Deployments rodando nos namespaces `shop`, `billing` e `analytics`.

O time de segurança recebeu alertas de que alguns workloads estão:

- lendo arquivos sensíveis do sistema (ex.: `/etc/shadow`), e/ou
- executando binários que **não fazem parte da imagem** (dropped binaries) / procurando chaves privadas.

## Tarefa

1. Use os **logs do Falco** para identificar quais Deployments dos namespaces `shop`, `billing` e `analytics` possuem Pods gerando esses alertas.
2. Escale **esses** Deployments para `0` réplicas (não os apague).
3. Grave-os em `/opt/course/22/q2/report.txt`, um por linha, no formato `<namespace>/<deployment>`.
4. Os demais Deployments devem permanecer inalterados e rodando.

> Dica de ambiente: o nome da unidade systemd do Falco depende do driver (`falco-modern-bpf`, `falco-kmod`, `falco-bpf`...).

## Documentação permitida

- https://falco.org/docs/
- https://falco.org/docs/reference/rules/default-rules/
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_scale/

Quando terminar: `bash verify.sh`
