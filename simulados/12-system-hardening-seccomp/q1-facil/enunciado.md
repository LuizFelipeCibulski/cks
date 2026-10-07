# Seccomp — Q1 (Fácil)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~4 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

No namespace `seccomp-q1` existem os Pods `web` e `legacy`. Uma auditoria apontou que eles rodam **sem
nenhum filtro seccomp**, permitindo que o processo chame qualquer syscall do kernel.

## Tarefa

1. Faça com que **todos os containers** dos Pods `web` e `legacy` rodem com o perfil seccomp **padrão do
   container runtime**, definido explicitamente no spec.
2. Os Pods devem manter os mesmos nomes, imagens e comandos, e estar `Running`.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

Quando terminar: `bash verify.sh`
