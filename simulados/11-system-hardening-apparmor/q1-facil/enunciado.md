# AppArmor — Q1 (Fácil)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~4 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

O time de segurança escreveu um perfil AppArmor que impede qualquer escrita em arquivos. Ele está em
`/opt/course/11/q1/k8s-deny-write` e ainda **não** foi carregado no kernel.

## Tarefa

1. Carregue o perfil `/opt/course/11/q1/k8s-deny-write` no nó `controlplane` em modo **enforce**.
2. Crie o Pod definido em `/opt/course/11/q1/pod.yaml` (Pod `writer`, namespace `apparmor-q1`) aplicando esse
   perfil AppArmor ao container `writer` usando os campos de `securityContext` (não use annotations).
3. O Pod deve estar `Running` e qualquer tentativa de escrita no filesystem do container deve ser negada.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://gitlab.com/apparmor/apparmor/-/wikis/Documentation

Quando terminar: `bash verify.sh`
