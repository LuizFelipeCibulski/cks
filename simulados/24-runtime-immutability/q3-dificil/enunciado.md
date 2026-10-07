# Immutability — Q3 (Difícil)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Ensure immutability of containers at runtime
**Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Nos namespaces `orion`, `pegasus` e `lyra` rodam vários Pods. A política da empresa define que um Pod é **imutável** somente se **todos** os seus containers (inclusive `initContainers`):

- (a) têm `readOnlyRootFilesystem: true`;
- (b) **não** são `privileged`;
- (c) **não** rodam como root (UID 0) — considere o UID efetivo resultante do `securityContext` do Pod e do container.

## Tarefa

1. Identifique todos os Pods desses três namespaces que **não** são imutáveis e grave-os em `/opt/course/24/q3/pods.txt`, um por linha, no formato `<namespace>/<pod>`.
2. Apague esses Pods. Os Pods imutáveis devem continuar rodando.
3. Crie uma `ValidatingAdmissionPolicy` chamada `require-readonly-rootfs` e uma `ValidatingAdmissionPolicyBinding` chamada `require-readonly-rootfs-binding` (ação `Deny`) que, **somente no namespace `lyra`**, rejeitem a criação/atualização de Pods em que **algum** container ou initContainer não tenha `securityContext.readOnlyRootFilesystem: true`. Mensagem: `readOnlyRootFilesystem required`.
4. O manifest original do Pod `lyra/frontend` foi salvo em `/opt/course/24/q3/frontend.yaml`. Corrija-o para que ele seja imutável segundo a política acima e recrie o Pod em `lyra`. O container `log-agent` deve continuar conseguindo gravar em `/tmp/agent.log`.

## Documentação permitida

- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
- https://kubernetes.io/docs/reference/kubectl/jsonpath/

Quando terminar: `bash verify.sh`
