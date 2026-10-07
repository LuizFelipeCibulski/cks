# Runtime Sandbox (gVisor) — Q2 (Médio)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~7 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane (instala o gVisor nos nós; leva ~1 min)
```

## Contexto
O namespace `untrusted` roda workloads de terceiros que processam arquivos enviados por usuários. A equipe decidiu isolá-los do kernel do host com o gVisor. O gVisor já está instalado nos nós, e alguém já criou algumas RuntimeClasses no cluster — mas **nem todas funcionam**.

## Tarefa
1. Descubra qual RuntimeClass existente realmente executa Pods com o **gVisor** (o handler precisa estar configurado no containerd dos nós). Grave somente o nome dela em `/opt/course/16/q2/runtimeclass.txt`. **Não** crie novas RuntimeClasses.
2. Faça **todos** os Deployments do namespace `untrusted` rodarem com essa RuntimeClass. Todas as réplicas devem ficar prontas.
3. Prove o isolamento: grave a saída do comando `dmesg` executado **dentro** de um Pod do Deployment `scanner` em `/opt/course/16/q2/dmesg.txt`.
4. O Deployment `portal` do namespace `trusted` deve continuar no runtime padrão (runc).

## Documentação permitida
- https://kubernetes.io/docs/concepts/containers/runtime-class/
- https://gvisor.dev/docs/user_guide/containerd/quick_start/
- https://gvisor.dev/docs/

Quando terminar: `bash verify.sh`
