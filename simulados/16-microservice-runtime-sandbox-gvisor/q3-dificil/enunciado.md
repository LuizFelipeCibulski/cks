# Runtime Sandbox (gVisor) — Q3 (Difícil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~12 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane
```
O setup informa o **nó alvo** (normalmente `node01`; em clusters de um só nó, o próprio controlplane) e o grava em `/opt/course/16/q3/target-node.txt`. Abaixo ele é chamado de `node01`.

## Contexto
Os binários do gVisor (`runsc` e `containerd-shim-runsc-v1`) foram copiados para `/usr/local/bin` do `node01`, mas o containerd do nó **ainda não sabe** que esse runtime existe. Nenhum outro nó terá gVisor. Os workloads do namespace `payments` precisam rodar isolados com gVisor e, portanto, **somente** no `node01`.

## Tarefa
1. No `node01` (`ssh node01`), registre no containerd um runtime com o nome de handler **`runsc`** (gVisor). **Não** sobrescreva nem remova a configuração existente do containerd (o runtime `runc` e suas opções, ex.: `SystemdCgroup`, devem continuar como estão). Atenção à versão do containerd / formato do `config.toml`. O nó deve continuar `Ready`.
2. Adicione ao `node01` a label `sandbox.cks.io/runtime=gvisor`.
3. Crie a RuntimeClass `gvisor-sandbox` com handler `runsc` que, por si só, garanta que os Pods que a usam sejam agendados apenas em nós com a label `sandbox.cks.io/runtime=gvisor` (sem precisar alterar nodeSelector/affinity nos Deployments).
4. Faça **todos** os Deployments do namespace `payments` usarem a RuntimeClass `gvisor-sandbox`. Todas as réplicas devem ficar prontas, rodando no `node01` sob o gVisor. Se algum Deployment não subir, investigue e corrija.
5. Grave a saída de `dmesg` executado dentro de um Pod do Deployment `gateway` em `/opt/course/16/q3/dmesg.txt`.
6. Pods comuns (sem RuntimeClass) devem continuar funcionando normalmente no `node01`.

## Documentação permitida
- https://kubernetes.io/docs/concepts/containers/runtime-class/ (inclui *Scheduling*)
- https://gvisor.dev/docs/user_guide/containerd/quick_start/
- https://gvisor.dev/docs/user_guide/install/
- https://github.com/containerd/containerd/blob/main/docs/cri/config.md

Quando terminar: `bash verify.sh`
