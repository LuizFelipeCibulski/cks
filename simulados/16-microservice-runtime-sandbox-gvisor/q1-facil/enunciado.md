# Runtime Sandbox (gVisor) — Q1 (Fácil)

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~4 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane (instala o gVisor nos nós; leva ~1 min)
```

## Contexto
O runtime **gVisor** (`runsc`) já está instalado e registrado no containerd de todos os nós com o nome de handler **`runsc`**. Ainda não existe nenhuma forma de os Pods usarem esse runtime.

## Tarefa
1. Crie uma **RuntimeClass** chamada `gvisor` que use o handler `runsc`.
2. Crie o Pod `sandboxed` no namespace `sandbox`, imagem `nginx:1.27-alpine`, que rode com essa RuntimeClass.
3. O Pod deve estar `Running`.

## Documentação permitida
- https://kubernetes.io/docs/concepts/containers/runtime-class/
- https://gvisor.dev/docs/user_guide/containerd/quick_start/

Quando terminar: `bash verify.sh`
