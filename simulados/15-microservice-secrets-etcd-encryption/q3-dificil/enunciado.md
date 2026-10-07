# Secrets — Q3 (Difícil) — Encryption at rest no etcd

**Domínio:** Minimize Microservice Vulnerabilities (20%) · **Tempo sugerido:** ~12 min

## Preparação
```bash
bash setup.sh   # rodar como root no controlplane (pode reiniciar o kube-apiserver)
```

## Contexto
Um pentest mostrou que qualquer pessoa com acesso ao etcd consegue ler os Secrets do cluster em texto puro. Um colega começou a configurar criptografia em repouso e deixou um rascunho em `/etc/kubernetes/etcd/ec.yaml`, mas **não terminou** e o kube-apiserver ainda não usa esse arquivo. O rascunho tem problemas.

O `etcdctl` está instalado no controlplane. Certificados de cliente do etcd: `/etc/kubernetes/pki/apiserver-etcd-client.{crt,key}` e CA `/etc/kubernetes/pki/etcd/ca.crt`.

## Tarefa
1. Corrija `/etc/kubernetes/etcd/ec.yaml` para que **novos** Secrets sejam gravados cifrados com o provider **`aescbc`** (ou `secretbox`), usando uma chave **aleatória de 32 bytes**, mas o kube-apiserver continue conseguindo **ler** Secrets antigos ainda não cifrados.
2. Configure o kube-apiserver para usar esse arquivo (mantendo o caminho `/etc/kubernetes/etcd/ec.yaml`). O kube-apiserver deve voltar a funcionar normalmente.
3. **Todos** os Secrets já existentes no cluster (em todos os namespaces) devem ficar cifrados no etcd.
4. Prove que funcionou: grave a saída de `etcdctl get` da chave do Secret `bank-creds` do namespace `bank` em `/opt/course/15/q3/etcd-bank-creds.txt`.
5. Os Secrets do namespace `bank` devem continuar legíveis via `kubectl` com os mesmos valores.

> Faça backup do manifest do kube-apiserver **fora** de `/etc/kubernetes/manifests` antes de editar.

## Documentação permitida
- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/reference/config-api/apiserver-config.v1/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

Quando terminar: `bash verify.sh`
