# Pod Security Standards — Q1 (Fácil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~4 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
O time *blue* roda suas aplicações no namespace `team-blue`. A equipe de segurança decidiu que, a partir de hoje, nenhum Pod privilegiado pode ser criado nesse namespace, usando o **Pod Security Admission** nativo do Kubernetes (sem webhooks externos).

Um desenvolvedor deixou um manifest em `/opt/course/13/q1/pod.yaml` que ele pretende aplicar.

## Tarefa
1. Configure o namespace `team-blue` para que o Pod Security Admission **aplique (enforce)** o nível **`baseline`**, usando a versão **`latest`** da política.
2. No mesmo namespace, configure **avisos (warn)** para o nível **`restricted`**.
3. Tente criar o Pod de `/opt/course/13/q1/pod.yaml`. Ele deve ser **rejeitado**. Grave a mensagem de erro completa retornada pelo `kubectl` em `/opt/course/13/q1/error.txt`.
4. O Pod `inventory` que já está rodando no namespace deve continuar rodando.

## Documentação permitida
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/

Quando terminar: `bash verify.sh`
