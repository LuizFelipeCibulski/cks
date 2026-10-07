# AppArmor — Q3 (Difícil)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~12 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

> Se o cluster não tiver `node01`, use o `controlplane` no lugar de `node01` em todos os itens (o setup avisa).

## Contexto

O Deployment `uploader` (namespace `apparmor-q3`) recebe arquivos de usuários e o time de segurança exige que
o processo **não consiga gravar** no diretório `/uploads` montado no container. Um colega começou o trabalho:
escreveu o perfil AppArmor em `/opt/course/11/q3/k8s-deny-uploads` (no `controlplane`) e alterou o Deployment,
mas os pods não sobem. Por política, esse perfil só deve existir nos nós rotulados para workloads com
AppArmor.

## Tarefa

1. Adicione o label `security=apparmor` ao nó `node01`.
2. Instale o perfil de `/opt/course/11/q3/k8s-deny-uploads` no `node01` em modo **enforce**, de forma que ele
   continue carregado após um reboot do nó. **Não altere o conteúdo do perfil.**
3. Corrija o Deployment `uploader` para que:
   - seus pods sejam agendados **somente** em nós com o label `security=apparmor`;
   - use o perfil definido no arquivo do item 2;
   - fique com **2/2** réplicas prontas.
4. Comprove o bloqueio: execute em um dos pods `touch /uploads/test` e grave a saída de erro completa desse
   comando em `/opt/course/11/q3/write-test.txt`. Escrita em `/tmp` deve continuar funcionando.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
- https://kubernetes.io/docs/tasks/configure-pod-container/assign-pods-nodes/
- https://gitlab.com/apparmor/apparmor/-/wikis/Documentation

Quando terminar: `bash verify.sh`
