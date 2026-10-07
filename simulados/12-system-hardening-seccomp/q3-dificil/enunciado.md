# Seccomp — Q3 (Difícil)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~12 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

> Se o cluster não tiver `node01`, use o `controlplane` no lugar de `node01` em todos os itens (o setup avisa).

## Contexto

O nó `node01` vai receber workloads de build não confiáveis. A política de segurança exige:

- que **todo** container que rodar no `node01` tenha um filtro seccomp por padrão, mesmo quando o Pod não
  declarar nenhum;
- que os containers de build não consigam criar diretórios.

Um colega deixou um rascunho do perfil em `/opt/course/12/q3/no-mkdir.json` (no `controlplane`), mas avisou que
"os pods nem sobem com ele".

## Tarefa

1. Configure o **kubelet do `node01`** para aplicar o perfil seccomp `RuntimeDefault` a todo container que não
   declarar um perfil. Use o arquivo de configuração do kubelet. O nó deve continuar `Ready`.
2. Corrija o perfil `/opt/course/12/q3/no-mkdir.json`: ele deve bloquear (retornando erro) **apenas** as
   syscalls `mkdir` e `mkdirat`; todas as demais syscalls devem ser permitidas. Instale-o no `node01` de modo que
   possa ser referenciado pelos Pods como `profiles/no-mkdir.json`.
3. O Deployment `builder` (namespace `seccomp-q3`) deve:
   - rodar **somente** no `node01`;
   - usar o perfil `profiles/no-mkdir.json` (tipo Localhost) no container `builder`;
   - ficar com **2/2** réplicas prontas.
   Dentro dos pods, `mkdir /tmp/x` deve falhar e `touch /tmp/x` deve funcionar.
4. O Pod `plain` (namespace `seccomp-q3`, no `node01`) deve estar `Running` **com filtro seccomp ativo**, sem
   que nenhum `seccompProfile` seja declarado no spec dele.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
- https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/

Quando terminar: `bash verify.sh`
