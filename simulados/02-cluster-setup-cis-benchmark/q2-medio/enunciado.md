# CIS Benchmark — Q2 (Médio)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # rodar como root no controlplane
```

## Contexto

Uma auditoria interna no controlplane encontrou desvios em relação ao CIS Kubernetes Benchmark no **kube-apiserver** e nos arquivos do control plane. O kube-bench está instalado no node.

## Tarefa

Corrija os seguintes achados do CIS Benchmark no controlplane:

1. **kube-apiserver**: o argumento `--profiling` deve estar de acordo com o benchmark.
2. **kube-apiserver**: o `--authorization-mode` deve incluir `Node` e `RBAC` e **não** pode incluir `AlwaysAllow`.
3. **Diretório PKI**: todos os arquivos e diretórios dentro de `/etc/kubernetes/pki` devem pertencer a `root:root`.
4. **Chaves privadas**: todos os arquivos `*.key` dentro de `/etc/kubernetes/pki` (incluindo subdiretórios) devem ter permissão `600` ou mais restritiva.
5. **Diretório de dados do etcd**: o data dir do etcd (descubra qual é) deve ter permissão `700` ou mais restritiva.
6. Depois de tudo corrigido e com o apiserver funcionando, rode o kube-bench com o target `master` e salve a saída completa em `/opt/course/02/q2/kube-bench-master.txt`.

> O cluster deve continuar funcional ao final (todos os pods do control plane `Running`).

## Documentação permitida

- https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
- https://kubernetes.io/docs/reference/access-authn-authz/authorization/
- https://kubernetes.io/docs/setup/best-practices/certificates/

Quando terminar: `bash verify.sh`
