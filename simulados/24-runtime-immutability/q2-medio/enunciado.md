# Immutability — Q2 (Médio)

**Domínio:** Monitoring, Logging and Runtime Security (20%) — Ensure immutability of containers at runtime
**Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

O time de segurança ativou `readOnlyRootFilesystem: true` em todos os containers do Deployment `web` (namespace `frontend`) e, desde então, a aplicação não funciona. O Deployment tem dois containers:

- `nginx` — serve o conteúdo de `/usr/share/nginx/html` na porta 80;
- `content` — gera periodicamente o `index.html` servido pelo nginx (volume compartilhado `html`).

## Tarefa

1. Mantenha `readOnlyRootFilesystem: true` em **ambos** os containers.
2. Descubra quais diretórios cada container realmente precisa gravar e torne **apenas** esses diretórios graváveis, usando volumes `emptyDir`.
   - Não monte volumes em `/`, `/etc`, `/usr`, `/var`, `/bin`, `/sbin`, `/lib` nem em `/etc/nginx`.
   - Não remova o volume `html` existente.
3. O Deployment deve ficar com todas as réplicas `Ready` e o nginx deve responder na porta 80 com o conteúdo **gerado pelo container `content`** (uma página contendo `generated at`).

## Documentação permitida

- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
- https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/

Quando terminar: `bash verify.sh`
