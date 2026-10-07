# CIS Benchmark — Q1 (Fácil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

A equipe de segurança rodou o **kube-bench** (já instalado no controlplane) e apontou que dois componentes do control plane expõem o endpoint de profiling (`/debug/pprof`), o que vaza informações detalhadas do sistema e aumenta a superfície de ataque.

## Tarefa

1. Rode o kube-bench contra os componentes do control plane (target `master`) **antes** de corrigir qualquer coisa e salve a saída completa em `/opt/course/02/q1/kube-bench-before.txt`.
2. Corrija o achado de profiling do **kube-controller-manager** de acordo com o CIS Benchmark.
3. Corrija o achado de profiling do **kube-scheduler** de acordo com o CIS Benchmark.
4. Garanta que os dois componentes voltaram a rodar (pods `Running` no namespace `kube-system`).
5. Rode o kube-bench novamente (target `master`) e salve a saída completa em `/opt/course/02/q1/kube-bench-after.txt`.

> Não altere o kube-apiserver nesta questão.

## Documentação permitida

- https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/
- https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/

Quando terminar: `bash verify.sh`
