# Security Context — Q1 (Fácil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~4 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto
O manifest `/opt/course/14/q1/pod.yaml` define o Pod `secure-app` no namespace `sec-ctx`, mas ele ainda não tem nenhuma configuração de segurança.

## Tarefa
Edite `/opt/course/14/q1/pod.yaml` (mantenha o arquivo atualizado com a versão final) e crie o Pod `secure-app` no namespace `sec-ctx` atendendo a:

1. **No nível do Pod:** processos rodam com UID `1000` e GID primário `3000`; volumes montados pertencem ao grupo suplementar `2000` (`fsGroup`).
2. **No container `app`:**
   - sistema de arquivos raiz **somente leitura**;
   - **não** permitir escalonamento de privilégio;
   - remover **todas** as Linux capabilities.
3. O diretório `/data` (volume `data` já presente no manifest) deve continuar gravável pelo container.
4. O Pod deve estar `Running`.

## Documentação permitida
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#security-context

Quando terminar: `bash verify.sh`
