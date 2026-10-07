# Soluções — 06 RBAC

> Conceitos: RBAC é **aditivo** (não existe "deny"); as permissões efetivas de um usuário são a
> **soma** de tudo que está ligado ao seu nome de usuário **e** aos seus grupos.
> - `Role` / `RoleBinding`: namespaced.
> - `ClusterRole`: definição reutilizável (ou para recursos cluster-scoped).
> - `ClusterRole` + `RoleBinding` = permissões da ClusterRole **somente no namespace da RoleBinding**.
> - `ClusterRole` + `ClusterRoleBinding` = permissões em **todos** os namespaces.
> - ServiceAccount como subject: `system:serviceaccount:<ns>:<nome>`.

---

## Q1 (Fácil) — Role + RoleBinding para ServiceAccount

```bash
kubectl -n finance create role pod-reader --verb=get,list,watch --resource=pods
kubectl -n finance create rolebinding report-bot-pod-reader \
  --role=pod-reader --serviceaccount=finance:report-bot
```

YAML equivalente:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: finance
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: report-bot-pod-reader
  namespace: finance
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: report-bot
  namespace: finance
```

**Validação:**

```bash
SA=system:serviceaccount:finance:report-bot
kubectl auth can-i list pods -n finance --as $SA      # yes
kubectl auth can-i delete pods -n finance --as $SA    # no
kubectl auth can-i get secrets -n finance --as $SA    # no
kubectl auth can-i list pods -n default --as $SA      # no
kubectl auth can-i --list -n finance --as $SA
```

**Pegadinhas**
- `--serviceaccount` usa o formato `<namespace>:<nome>` (com dois-pontos), **não** o
  `system:serviceaccount:...`. Já no `--as` é o nome completo.
- Esquecer o `-n finance` cria a Role no `default`.
- `roleRef` é imutável: se errar, apague e recrie a RoleBinding.

Doc: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole

---

## Q2 (Médio) — ClusterRole reutilizável + RoleBindings por namespace

```bash
# 1. ClusterRole
kubectl create clusterrole app-viewer --verb=get,list,watch \
  --resource=deployments.apps,configmaps

# 2. jane só em team-a
kubectl -n team-a create rolebinding jane-app-viewer --clusterrole=app-viewer --user=jane

# 3. SA ci só em team-b
kubectl -n team-b create rolebinding ci-app-viewer --clusterrole=app-viewer --serviceaccount=team-b:ci
```

ClusterRole em YAML (observe os dois grupos de API):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-viewer
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
```

### 4. Investigar a SA legacy

```bash
L=system:serviceaccount:team-b:legacy
kubectl auth can-i list pods -n team-a --as $L                 # yes
kubectl auth can-i get secrets -n team-a --as $L               # no
kubectl auth can-i delete deployments.apps -n team-a --as $L   # no
# ou tudo de uma vez:
kubectl auth can-i --list -n team-a --as $L

# de onde vem? procurar bindings que citam a SA
kubectl get rolebindings,clusterrolebindings -A -o wide | grep legacy
```

Ela tem a ClusterRole `view` em `team-a` (RoleBinding `legacy-access`). A `view` padrão **não**
inclui Secrets (justamente para não vazar tokens/credenciais) nem verbos de escrita.

```bash
cat > /opt/course/6/q2/legacy.txt <<'EOF'
list-pods-team-a: yes
get-secrets-team-a: no
delete-deployments-team-a: no
EOF
```

**Pegadinhas**
- `--as jane` testa só o usuário; se a questão envolver grupo, use também `--as-group`.
- Usar ClusterRoleBinding em vez de RoleBinding dá acesso a **todos** os namespaces — erro
  clássico que reprova a questão.
- Recursos de `apps` em `can-i`: use `deployments.apps` (ou `deployments`, que é resolvido).
- Uma SA de um namespace pode receber permissões em **outro** namespace — a RoleBinding fica no
  namespace onde a permissão vale, o subject aponta para o namespace da SA.

Doc: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#rolebinding-and-clusterrolebinding

---

## Q3 (Difícil) — usuário com certificado (CSR) + permissões mínimas + limpeza

### 1. Chave e CSR com openssl

```bash
cd /opt/course/6/q3
openssl genrsa -out dev-maria.key 2048
openssl req -new -key dev-maria.key -out dev-maria.csr -subj "/CN=dev-maria/O=developers"
```

No certificado de cliente: **CN = nome do usuário**, **O = grupo(s)**.

### 2. CertificateSigningRequest (exemplo pronto na doc "Normal user")

```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-maria
spec:
  request: $(base64 -w0 < dev-maria.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

kubectl get csr dev-maria                 # Pending
kubectl certificate approve dev-maria
kubectl get csr dev-maria -o jsonpath='{.status.certificate}' | base64 -d > dev-maria.crt
openssl x509 -in dev-maria.crt -noout -subject -enddate
```

### 3. kubeconfig

```bash
KC=/opt/course/6/q3/dev-maria.kubeconfig
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

kubectl config set-cluster kubernetes --kubeconfig=$KC --server=$SERVER \
  --certificate-authority=/etc/kubernetes/pki/ca.crt --embed-certs=true
kubectl config set-credentials dev-maria --kubeconfig=$KC \
  --client-certificate=dev-maria.crt --client-key=dev-maria.key --embed-certs=true
kubectl config set-context dev-maria --kubeconfig=$KC --cluster=kubernetes --user=dev-maria --namespace=project-x
kubectl config use-context dev-maria --kubeconfig=$KC

kubectl --kubeconfig=$KC auth whoami
# Username: dev-maria   Groups: [developers system:authenticated]
```

### 4. Permissões mínimas

```bash
kubectl -n project-x create role pod-developer --verb=get,list,watch,create,delete --resource=pods
# acrescentar pods/log (subrecurso) só com get:
kubectl -n project-x edit role pod-developer
kubectl -n project-x create rolebinding dev-maria-pod-developer --role=pod-developer --user=dev-maria
```

Role completa:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-developer
  namespace: project-x
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

(`kubectl create role ... --resource=pods,pods/log` daria os mesmos verbos aos dois; como
`pods/log` só deve ter `get`, faça duas regras.)

### 5. Encontrar as permissões excessivas — a pegadinha do grupo

Teste com o **kubeconfig real** (inclui o grupo `developers` do certificado):

```bash
kubectl --kubeconfig=$KC auth can-i '*' '*'                       # yes  -> algo errado!
kubectl --kubeconfig=$KC auth can-i --list -n project-x
# equivalente por impersonation:
kubectl auth can-i '*' '*' --as dev-maria --as-group developers
```

Procure bindings para o usuário **e** para o grupo:

```bash
kubectl get clusterrolebindings -o wide | grep -E 'dev-maria|developers'
kubectl get rolebindings -A -o wide     | grep -E 'dev-maria|developers'
# com jq, mais preciso:
kubectl get clusterrolebindings,rolebindings -A -o json | jq -r '.items[] |
  select(.subjects[]? | .name=="dev-maria" or .name=="developers") |
  "\(.kind) \(.metadata.namespace // "-") \(.metadata.name) -> \(.roleRef.name)"'
```

Resultado esperado: `ClusterRoleBinding developers-admin` (grupo `developers` -> `cluster-admin`)
e `RoleBinding project-x/project-x-legacy-editors` (`dev-maria` -> `edit`).

```bash
kubectl delete clusterrolebinding developers-admin
kubectl -n project-x delete rolebinding project-x-legacy-editors
```

> Apague o **binding**, nunca a ClusterRole `cluster-admin`/`edit` (outros dependem delas).

### 6. ServiceAccount ci-runner sem permissões cluster-wide

```bash
kubectl get clusterrolebindings -o wide | grep ci-runner
# ci-pipeline-deployer   ClusterRole/cluster-admin ... project-x/ci-runner
kubectl delete clusterrolebinding ci-pipeline-deployer
kubectl -n project-x get rolebinding ci-runner-view -o wide    # mantém
```

### Validação manual

```bash
KC=/opt/course/6/q3/dev-maria.kubeconfig
for c in "create pods" "delete pods" "get pods --subresource=log" \
         "create pods --subresource=exec" "create deployments" "get secrets"; do
  echo "$c: $(kubectl --kubeconfig=$KC auth can-i $c -n project-x)"
done
kubectl --kubeconfig=$KC auth can-i list pods -n default      # no
kubectl --kubeconfig=$KC auth can-i get nodes                  # no
SA=system:serviceaccount:project-x:ci-runner
kubectl auth can-i --list --as $SA | head
```

**Pegadinhas**
- O `O=` do certificado vira **grupo**: um binding antigo para o grupo dá permissões que não
  aparecem em `kubectl auth can-i --as dev-maria` (sem `--as-group`). Teste com o kubeconfig.
- `pods/exec` é um subrecurso com verbo `create` (e `get` para websockets antigos) — não
  coloque `pods/*` ou `*`.
- `request` do CSR é o arquivo `.csr` inteiro em base64 **sem quebra de linha** (`base64 -w0`).
- `usages` precisa incluir `client auth`; signer `kubernetes.io/kube-apiserver-client`.
- Certificados não podem ser revogados no Kubernetes: por isso validade curta
  (`expirationSeconds`) e RBAC mínimo importam.
- Sem `--embed-certs` o kubeconfig referencia caminhos de arquivo; funciona, mas quebra se os
  arquivos forem movidos.

Docs:
- https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/#normal-user
- https://kubernetes.io/docs/reference/access-authn-authz/rbac/
