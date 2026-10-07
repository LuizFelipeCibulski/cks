# Supply Chain Security — Q2 (Médio)

**Domínio:** Supply Chain Security (20%) — Secure your supply chain: whitelist allowed registries
**Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

A empresa decidiu que, nos namespaces marcados como "enforced", somente imagens de registries confiáveis podem ser executadas. Os registries confiáveis são:

- `registry.k8s.io/`
- `registry.cks.local:5000/`

Não há nenhum admission webhook externo disponível: a regra deve ser implementada **nativamente** pelo kube-apiserver, com CEL.

Os namespaces `team-blue` e `team-green` já existem e possuem Pods em execução.

## Tarefa

1. Crie uma `ValidatingAdmissionPolicy` chamada `trusted-registries` (API `admissionregistration.k8s.io/v1`) que valide a criação e atualização de **Pods** e rejeite qualquer Pod em que **algum** container — incluindo `initContainers` — use imagem que não comece com um dos registries confiáveis acima. A mensagem de erro deve ser exatamente: `image registry not trusted`.
2. Crie uma `ValidatingAdmissionPolicyBinding` chamada `trusted-registries-binding` com a ação `Deny`, que aplique a policy **somente** a namespaces com o label `registry-policy=enforced`.
3. Aplique o label `registry-policy=enforced` no namespace `team-blue`. O namespace `team-green` **não** deve ser afetado.
4. Policies de admissão não afetam Pods já em execução. Identifique os Pods **já existentes** em `team-blue` que violam a regra e grave seus nomes (um por linha) em `/opt/course/21/q2/violations.txt`. Não apague esses Pods.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/reference/using-api/cel/
- https://kubernetes.io/docs/concepts/containers/images/#image-names

Quando terminar: `bash verify.sh`
