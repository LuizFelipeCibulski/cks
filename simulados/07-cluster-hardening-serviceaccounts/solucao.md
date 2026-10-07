# Soluções — 07 ServiceAccounts

> Conceitos:
> - Todo Pod roda com uma ServiceAccount (se nada for dito, a `default` do namespace).
> - Por padrão o kubelet monta um **token projetado** (volume `kube-api-access-xxxxx`) em
>   `/var/run/secrets/kubernetes.io/serviceaccount/` (`token`, `ca.crt`, `namespace`).
>   Se o container for comprometido, o atacante usa esse token contra a API.
> - `automountServiceAccountToken: false` pode ser definido **na SA** e/ou **no Pod**; o valor do
>   Pod tem precedência.
> - Desde a 1.24 não são criados Secrets de token automaticamente; tokens são emitidos pela
>   TokenRequest API (`kubectl create token`, volumes projetados) — curtos, com audience e
>   vinculados ao Pod.

---

## Q1 (Fácil) — SA sem automount + Pod

```bash
kubectl -n payments create serviceaccount backend-sa
kubectl -n payments patch sa backend-sa -p '{"automountServiceAccountToken": false}'

kubectl -n payments run backend --image=nginx:1.27-alpine \
  --overrides='{"spec":{"serviceAccountName":"backend-sa"}}'
```

Ou em YAML:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: payments
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: payments
spec:
  serviceAccountName: backend-sa
  automountServiceAccountToken: false   # opcional aqui (defesa em profundidade)
  containers:
  - name: backend
    image: nginx:1.27-alpine
```

**Validação**

```bash
kubectl -n payments get pod backend -o jsonpath='{.spec.volumes}'      # sem kube-api-access
kubectl -n payments exec backend -- ls /var/run/secrets/kubernetes.io/serviceaccount
# ls: ... No such file or directory
```

**Pegadinhas**
- Mudar a SA depois que o Pod existe não remove o volume: `serviceAccountName` e volumes de Pod
  são imutáveis — recrie o Pod (`kubectl replace --force -f pod.yaml`).
- `kubectl run --serviceaccount` foi removido; use `--overrides` ou YAML
  (`kubectl run ... --dry-run=client -o yaml > pod.yaml`).

Doc: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#opt-out-of-api-credential-automounting

---

## Q2 (Médio) — tirar o Deployment da SA default + token de curta duração

```bash
# 1. SA dedicada e Deployment usando-a
kubectl -n orders create serviceaccount orders-web-sa
kubectl -n orders set serviceaccount deployment orders-web orders-web-sa

# 2. Pods do deployment sem token (no pod template)
kubectl -n orders patch deployment orders-web \
  -p '{"spec":{"template":{"spec":{"automountServiceAccountToken":false}}}}'
#    (alternativa: automountServiceAccountToken: false na SA orders-web-sa)

# 3. SA default sem automount
kubectl -n orders patch sa default -p '{"automountServiceAccountToken": false}'

kubectl -n orders rollout status deploy/orders-web
```

Trecho do Deployment após as mudanças (`kubectl -n orders edit deploy orders-web`):

```yaml
spec:
  template:
    spec:
      serviceAccountName: orders-web-sa
      automountServiceAccountToken: false
      containers:
      - name: nginx
        image: nginx:1.27-alpine
```

```bash
# 4. token de 1h via TokenRequest API
kubectl -n orders create token orders-ci --duration=1h > /opt/course/7/q2/orders-ci.token
```

**Validação**

```bash
kubectl -n orders get pods -o custom-columns=N:.metadata.name,SA:.spec.serviceAccountName,VOL:.spec.volumes[*].name
# decodificar o JWT (campos exp - iat = 3600)
cut -d. -f2 /opt/course/7/q2/orders-ci.token | tr '_-' '/+' | base64 -d 2>/dev/null; echo
# testar o token direto na API (deve autenticar como system:serviceaccount:orders:orders-ci;
# 403 aqui é normal, pois a SA não tem permissão para listar pods)
curl -sk -H "Authorization: Bearer $(cat /opt/course/7/q2/orders-ci.token)" \
  https://$(hostname -i | awk '{print $1}'):6443/api/v1/namespaces/orders/pods | head
```

**Pegadinhas**
- `automountServiceAccountToken: false` na SA **default** não afeta Pods que já estão rodando —
  só os que forem criados depois (por isso o rollout).
- O campo vai em `spec.template.spec`, não em `spec` do Deployment.
- Não use Secret `kubernetes.io/service-account-token`: é um token **sem expiração** (legado).
- `kubectl create token` imprime só o JWT na saída — é exatamente o que deve ir no arquivo.
- O apiserver pode limitar a duração máxima (`--service-account-max-token-expiration`).

Docs:
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/
- https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/

---

## Q3 (Difícil) — token projetado com audience correta e RBAC mínimo

### Diagnóstico

```bash
kubectl -n observer get pod pod-lister -o yaml | less
kubectl -n observer exec pod-lister -- sh -c 'curl -sk -H "Authorization: Bearer $(cat /var/run/secrets/tokens/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/observer/pods'
# 401 Unauthorized  -> o token tem audience "vault"; o apiserver não aceita
```

Descobrir a audience aceita pelo apiserver:

```bash
grep -E 'api-audiences|service-account-issuer' /etc/kubernetes/manifests/kube-apiserver.yaml
# - --service-account-issuer=https://kubernetes.default.svc.cluster.local
```

Sem `--api-audiences`, o apiserver aceita como audience os valores de
`--service-account-issuer` (no kubeadm: `https://kubernetes.default.svc.cluster.local`).
Omitir `audience` no volume projetado também gera token com a audience padrão do apiserver.

### 1 e 2. SA + RBAC mínimo

```bash
kubectl -n observer create serviceaccount pod-lister-sa
kubectl -n observer patch sa pod-lister-sa -p '{"automountServiceAccountToken": false}'
kubectl -n observer create role pod-list --verb=get,list --resource=pods
kubectl -n observer create rolebinding pod-lister-sa-pod-list --role=pod-list --serviceaccount=observer:pod-lister-sa
```

### 3. Pod corrigido

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-lister
  namespace: observer
  labels:
    app: pod-lister
spec:
  serviceAccountName: pod-lister-sa
  automountServiceAccountToken: false
  containers:
  - name: lister
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "sleep 1d"]
    volumeMounts:
    - name: api-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          audience: https://kubernetes.default.svc.cluster.local
          expirationSeconds: 3600
      - configMap:
          name: kube-root-ca.crt
          items:
          - key: ca.crt
            path: ca.crt
```

```bash
kubectl replace --force -f /opt/course/7/q3/pod-lister.yaml     # Pod é imutável: recria
kubectl -n observer exec pod-lister -- sh -c 'curl -s --cacert /var/run/secrets/tokens/ca.crt \
  -H "Authorization: Bearer $(cat /var/run/secrets/tokens/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/observer/pods | head'
```

> O ConfigMap `kube-root-ca.crt` existe em todo namespace (publicado pelo controller-manager) —
> é a mesma fonte que o volume `kube-api-access` padrão usa.

### 4. Os outros workloads

```bash
# SA default sem automount (afeta web e cache, que usam a default)
kubectl -n observer patch sa default -p '{"automountServiceAccountToken": false}'
# (ou automountServiceAccountToken: false no template de cada Deployment)
kubectl -n observer rollout restart deploy web cache

# permissão excessiva da SA default
kubectl -n observer get rolebindings -o wide
kubectl -n observer delete rolebinding default-edit
```

**Validação**

```bash
kubectl auth can-i list pods -n observer --as system:serviceaccount:observer:default      # no
kubectl auth can-i --list -n observer --as system:serviceaccount:observer:pod-lister-sa
kubectl -n observer get pods -o custom-columns=N:.metadata.name,SA:.spec.serviceAccountName,VOL:.spec.volumes[*].name
```

**Pegadinhas**
- Token com audience diferente (ex: `vault`) é válido para **outro** serviço e o apiserver
  responde **401**. Isso é uma proteção: um token emitido para o Vault não pode ser reutilizado
  contra a API (e vice-versa).
- `expirationSeconds` mínimo é 600; o kubelet renova o token projetado automaticamente
  (a 80% da validade) — a aplicação deve reler o arquivo.
- Sem `automountServiceAccountToken: false`, o Pod receberia **dois** tokens (o padrão e o seu).
- `401` = problema de autenticação (token/audience); `403` = autenticou mas falta RBAC.
- Usar `-k` no curl "funciona", mas o enunciado pede validar com a CA.
- `rollout restart` é necessário: Pods antigos mantêm o volume do token.

Docs:
- https://kubernetes.io/docs/concepts/storage/projected-volumes/#serviceaccounttoken
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#launch-a-pod-using-service-account-token-projection
- https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/#without-using-a-proxy
