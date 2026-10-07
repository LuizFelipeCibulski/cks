# Supply Chain Security — Q3 (Difícil)

**Domínio:** Supply Chain Security (20%) — Secure your supply chain / admission control de imagens
**Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane (reinicia o kube-apiserver)
```

## Contexto

Um colega começou a configurar o admission plugin **ImagePolicyWebhook** no kube-apiserver, mas saiu de férias com o trabalho pela metade. Os arquivos de configuração estão em `/etc/kubernetes/policywebhook/`:

- `admission_config.json` — AdmissionConfiguration do apiserver
- `kubeconf` — kubeconfig usado pelo apiserver para falar com o serviço externo de validação de imagens
- certificados `*.pem`

O serviço externo de validação ficará disponível **no futuro** em `https://localhost:1234`. Ele ainda não existe.

## Tarefa

1. Corrija `/etc/kubernetes/policywebhook/admission_config.json` para que ele aponte para o kubeconfig correto existente no diretório.
2. Configure o `allowTTL` para `100`.
3. Garanta que **toda criação de Pod seja negada** caso o serviço externo não esteja acessível (fail closed).
4. Configure o `kubeconf` para que o serviço externo seja contatado em `https://localhost:1234`.
5. Habilite o admission plugin `ImagePolicyWebhook` no kube-apiserver (mantendo os plugins já habilitados) e passe a configuração com a flag adequada. Garanta que os arquivos estejam acessíveis **dentro** do container do apiserver.
6. O kube-apiserver deve voltar a responder normalmente. Como o serviço externo ainda não existe, a criação de qualquer Pod novo deve ser negada.

> O backup do manifest original fica em `/root/cks-backup/kube-apiserver.yaml`. Depois de passar no `verify.sh`, restaure o apiserver original (veja a `solucao.md`) — caso contrário nenhum Pod novo poderá ser criado no cluster.

## Documentação permitida

- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/tasks/debug/debug-cluster/

Quando terminar: `bash verify.sh`
