# D7: Encryption at rest de Secrets no etcd

**Domínio:** Minimize Microservice Vulnerabilities · **Tempo-alvo:** 9 min

## Preparação

```bash
bash setup.sh   # root, no controlplane (restaura o apiserver original)
```

## Contexto

No namespace `d7` existem as Secrets `db-creds` e `api-token`. Hoje elas estão em texto puro no etcd.

## Tarefa

1. Crie `/etc/kubernetes/enc/enc.yaml` (`EncryptionConfiguration`) para o recurso `secrets` com:
   - provider `aescbc` com uma chave chamada `key1` (32 bytes aleatórios em base64) como provider **principal**;
   - `identity` como fallback, para ainda conseguir ler dados antigos.
2. Configure o `kube-apiserver` para usar esse arquivo. O apiserver deve voltar a funcionar.
3. Garanta que **todas** as Secrets já existentes no namespace `d7` estejam criptografadas no etcd.
4. Grave em `/opt/course/25/d7/etcd.txt` a saída de um `etcdctl get` da chave da secret `d7/db-creds`
   (deve mostrar o prefixo `k8s:enc:aescbc:v1:key1`).

## Documentação permitida

- https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
- https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/

Quando terminar: `bash verify.sh`
