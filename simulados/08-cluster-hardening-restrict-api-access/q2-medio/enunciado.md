# Restrict API Access — Q2 (Médio)

**Domínio:** Cluster Hardening (15%) — Restrict access to Kubernetes API
**Tempo sugerido:** ~7 minutos

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Uma auditoria no cluster kubeadm encontrou as seguintes não conformidades no kube-apiserver
(static pod em `/etc/kubernetes/manifests/kube-apiserver.yaml`):

- o kube-apiserver está exposto para fora do cluster através de um **NodePort**;
- o kube-apiserver aceita requisições **anônimas**;
- kubelets conseguem alterar labels protegidos dos seus próprios Node objects.

## Tarefa

1. O kube-apiserver **não** deve mais ser exposto via NodePort: o Service `kubernetes` do
   namespace `default` deve ser do tipo `ClusterIP` e nenhuma porta de node deve encaminhar para
   o apiserver.
2. Desabilite a autenticação anônima: requisições sem credenciais a `/api` devem receber
   **HTTP 401**.
3. Habilite o admission plugin que restringe o que um kubelet pode modificar em objetos `Node` e
   `Pod` (impede, por exemplo, que um kubelet adicione labels
   `node-restriction.kubernetes.io/*` ao próprio node).
4. O kube-apiserver deve continuar funcionando e o `kubectl` como admin deve continuar operando.

> Faça backup do manifest **fora** de `/etc/kubernetes/manifests/` antes de editá-lo.

## Documentação permitida

- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#anonymous-requests
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/
- https://kubernetes.io/docs/concepts/security/controlling-access/

Quando terminar: `bash verify.sh`
