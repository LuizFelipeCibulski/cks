# Pod Security Standards — Q3 (Difícil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~12 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane (reinicia o kube-apiserver se necessário)
```

## Contexto
O Deployment `checkout-api` no namespace `checkout` está rodando há meses sem nenhuma restrição. A auditoria exigiu que o namespace passe a cumprir o Pod Security Standard **restricted** e que o cluster tenha uma configuração padrão de Pod Security definida no próprio kube-apiserver.

## Tarefa
**Parte A — namespace**
1. Faça o namespace `checkout` **aplicar (enforce)** o nível `restricted` (versão `latest`).
2. Execute `kubectl -n checkout rollout restart deploy checkout-api`. Os novos Pods não vão aparecer. Descubra o motivo e grave a mensagem de erro (a linha do evento que explica por que os Pods não podem ser criados) em `/opt/course/13/q3/reason.txt`.
3. Corrija o Deployment `checkout-api` para que ele seja **compatível com `restricted`** e volte a ter **2/2 réplicas prontas**, sem remover a label de enforce do namespace. Requisitos:
   - Nenhum container (inclusive initContainers) pode ser privilegiado ou permitir escalonamento de privilégio;
   - Todos os containers rodam como não-root (`runAsNonRoot: true`), com o perfil seccomp `RuntimeDefault` e removendo **todas** as capabilities;
   - Volumes `hostPath` não são permitidos: substitua por `emptyDir` mantendo o mesmo nome e o mesmo `mountPath`;
   - A aplicação deve continuar respondendo HTTP na porta `8080` dentro do Pod.

**Parte B — padrão do cluster (kube-apiserver)**

4. Crie o arquivo `/etc/kubernetes/psa/podsecurity.yaml` com um `AdmissionConfiguration` para o plugin `PodSecurity` com:
   - defaults: `enforce: privileged`, `audit: restricted`, `warn: baseline` (todas as versões `latest`);
   - exemptions: os namespaces `kube-system` e `legacy-batch`.
5. Configure o kube-apiserver para usar esse arquivo. O namespace `legacy-batch` (que já existe e tem a label `enforce=restricted`) deve passar a aceitar Pods privilegiados **sem** que você remova ou altere suas labels.

> Faça backup do manifest do kube-apiserver **fora** de `/etc/kubernetes/manifests` antes de editar.

## Documentação permitida
- https://kubernetes.io/docs/concepts/security/pod-security-admission/
- https://kubernetes.io/docs/concepts/security/pod-security-standards/
- https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/
- https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

Quando terminar: `bash verify.sh`
