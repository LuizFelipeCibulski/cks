# Seccomp — Q2 (Médio)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~7 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

O time de segurança criou um perfil seccomp customizado que impede a alteração de permissões de arquivos.
Ele está em `/opt/course/12/q2/block-chmod.json`. O manifesto do Pod que deve usá-lo está em
`/opt/course/12/q2/pod.yaml` (o Pod roda no nó `controlplane`).

## Tarefa

1. Disponibilize o perfil para o kubelet do `controlplane` no diretório padrão de perfis seccomp do kubelet,
   dentro do subdiretório `profiles/`, mantendo o nome de arquivo `block-chmod.json`.
2. Crie o Pod `hardened` (namespace `seccomp-q2`) a partir de `/opt/course/12/q2/pod.yaml`, aplicando o perfil
   ao container `app` como perfil seccomp do tipo **Localhost**. O Pod deve estar `Running`.
3. Dentro do container, crie o arquivo `/tmp/secret`, tente mudar sua permissão para `600` e grave a
   **mensagem de erro** obtida em `/opt/course/12/q2/chmod.txt`.
4. Grave em `/opt/course/12/q2/seccomp-mode.txt` apenas o valor do campo `Seccomp` de
   `/proc/1/status` do container `app`.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/seccomp/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/

Quando terminar: `bash verify.sh`
