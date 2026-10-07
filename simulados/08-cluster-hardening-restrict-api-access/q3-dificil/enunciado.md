# Restrict API Access — Q3 (Difícil)

**Domínio:** Cluster Hardening (15%) — Restrict access to Kubernetes API
**Tempo sugerido:** ~12 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O kube-apiserver deste cluster foi "configurado às pressas" para um teste de integração e nunca
mais foi revisado. Ele está em `/etc/kubernetes/manifests/kube-apiserver.yaml`. Há relatos de que
**qualquer um** consegue fazer qualquer coisa no cluster, inclusive sem credenciais, e de que
existe uma credencial "de emergência" desconhecida com acesso total.

## Tarefa

Corrija o cluster para atender **todos** os requisitos abaixo, sem quebrar o kube-apiserver:

1. Requisições **não autenticadas** a `/api` devem receber **HTTP 401**. (É permitido manter
   apenas os endpoints de health `/livez`, `/readyz` e `/healthz` acessíveis anonimamente, se
   você julgar necessário.)
2. O kube-apiserver deve usar os modos de autorização `Node` e `RBAC` (nessa ordem) e nenhum
   outro.
3. O admission plugin `NodeRestriction` deve estar habilitado.
4. Não pode existir nenhum ClusterRoleBinding que conceda permissões ao usuário
   `system:anonymous` ou ao grupo `system:unauthenticated`, exceto o padrão
   `system:public-info-viewer`.
5. Encontre a credencial "de emergência" configurada no kube-apiserver. Grave o **nome do
   usuário** associado a ela em `/opt/course/8/q3/backdoor.txt` e garanta que ela não autentique
   mais no cluster.
6. Ao final, `kubectl` (admin), kubelets e o restante do control plane devem continuar
   funcionando normalmente.

> Faça backup do manifest **fora** de `/etc/kubernetes/manifests/` antes de editá-lo. Se o
> apiserver não subir, consulte os logs em `/var/log/pods/kube-system_kube-apiserver-*/` ou
> `crictl ps -a` / `crictl logs`.

## Documentação permitida

- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/
- https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- https://kubernetes.io/docs/reference/access-authn-authz/node/
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

Quando terminar: `bash verify.sh`
