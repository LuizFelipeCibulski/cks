# Supply Chain Security — Q1 (Fácil)

**Domínio:** Supply Chain Security (20%) — Secure your supply chain: whitelist allowed registries, sign and validate images
**Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O time de segurança detectou que a tag de uma imagem foi sobrescrita no registry público por uma versão diferente. Tags são **mutáveis**; para garantir que o cluster sempre rode exatamente o mesmo conteúdo, as imagens devem ser referenciadas por **digest**.

No namespace `supply-chain` existe o Deployment `payment-api`, com os containers `api` e `log-agent`, ambos referenciando imagens por tag.

## Tarefa

1. Altere o Deployment `payment-api` (namespace `supply-chain`) para que **os dois containers** referenciem a imagem por digest, no formato `<repositório>@sha256:<digest>`, **sem tag**.
2. Os digests usados devem ser **exatamente os das imagens que os Pods do Deployment estão executando agora** (ou seja, o conteúdo em execução não pode mudar).
3. O rollout deve terminar com sucesso e todos os Pods devem ficar `Running`/`Ready`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/containers/images/#image-names
- https://kubernetes.io/docs/reference/kubectl/jsonpath/
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment

Quando terminar: `bash verify.sh`
