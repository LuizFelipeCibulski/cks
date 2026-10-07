# AppArmor — Q2 (Médio)

**Domínio:** System Hardening (10%) — *Use kernel hardening tools such as AppArmor, seccomp*
**Tempo sugerido:** ~7 minutos

## Preparação

No nó `controlplane`, como root:

```bash
bash setup.sh
```

## Contexto

O site servido pelo Deployment `web` (namespace `apparmor-q2`) sofreu um *defacement*. O time de segurança
criou o perfil AppArmor `k8s-nginx-ro` (arquivo em `/etc/apparmor.d/k8s-nginx-ro` no `controlplane`), que
impede alterações no conteúdo publicado. Os pods do `web` rodam somente no `controlplane`.

## Tarefa

1. O perfil `k8s-nginx-ro` está carregado no kernel, mas **não está bloqueando nada**. Corrija isso para que
   ele passe a **impor** as regras (sem alterar o conteúdo do arquivo do perfil).
2. Grave em `/opt/course/11/q2/enforced.txt` o nome de **todos** os perfis AppArmor carregados no
   `controlplane` em modo enforce cujo nome começa com `k8s-` (um por linha), **após** o item 1.
3. Altere o Deployment `web` para que:
   - o container `nginx` use o perfil `k8s-nginx-ro`;
   - o container `logger` use explicitamente o perfil **padrão do container runtime**.
4. O Deployment deve ficar com todas as réplicas prontas, e uma tentativa de escrever em
   `/usr/share/nginx/html/index.html` dentro do container `nginx` deve falhar.

## Documentação permitida

- https://kubernetes.io/docs/tutorials/security/apparmor/
- https://gitlab.com/apparmor/apparmor/-/wikis/Documentation

Quando terminar: `bash verify.sh`
