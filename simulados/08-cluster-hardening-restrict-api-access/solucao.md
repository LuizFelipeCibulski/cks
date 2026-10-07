# Soluções — 08 Restrict API Access

> Toda requisição ao kube-apiserver passa por: **Autenticação** (quem é você?) ->
> **Autorização** (pode fazer isso? `--authorization-mode`) -> **Admission** (a mudança é
> permitida/precisa ser alterada?). Uma requisição sem credenciais vira o usuário
> `system:anonymous` (grupo `system:unauthenticated`) se `--anonymous-auth` estiver ligado
> (o padrão é `true`). Com RBAC, anônimos só podem o que estiver ligado a eles por bindings —
> por padrão apenas `system:public-info-viewer` (`/healthz`, `/livez`, `/readyz`, `/version`).
>
> **Regra de ouro ao editar o static pod do apiserver:**
> ```bash
> mkdir -p /root/cks-backup
> cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/cks-backup/kube-apiserver.yaml.$(date +%s)
> # NUNCA deixe a cópia dentro de /etc/kubernetes/manifests/ (o kubelet tentaria subir os dois)
> vim /etc/kubernetes/manifests/kube-apiserver.yaml
> watch crictl ps            # esperar o container kube-apiserver novo (pode levar ~30-60s)
> ```
> Se não subir: `crictl ps -a | grep apiserver`, `crictl logs <id>`,
> `tail /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log`,
> `journalctl -u kubelet | tail` (erros de YAML aparecem no kubelet).

---

## Q1 (Fácil) — bindings perigosos para anônimos

```bash
# listar ClusterRoleBindings e seus subjects
kubectl get clusterrolebindings -o wide | grep -E 'system:anonymous|system:unauthenticated'

# mais preciso (wide corta colunas):
kubectl get clusterrolebindings -o json | jq -r '.items[] |
  select(.subjects[]? | .name=="system:anonymous" or .name=="system:unauthenticated") |
  "\(.metadata.name) -> \(.roleRef.name)"' | sort -u
# kubelet-debug-access  -> node-debug-reader
# metrics-public-access -> view
# system:public-info-viewer -> system:public-info-viewer   (padrão, manter!)

printf 'kubelet-debug-access\nmetrics-public-access\n' > /opt/course/8/q1/removidos.txt
kubectl delete clusterrolebinding kubelet-debug-access metrics-public-access
```

Sem jq: `kubectl get clusterrolebindings -o custom-columns=N:.metadata.name,S:.subjects[*].name | grep -E 'anonymous|unauthenticated'`.

**Validação**

```bash
kubectl auth can-i list secrets -A --as system:anonymous --as-group system:unauthenticated   # no
curl -sk https://localhost:6443/api/v1/namespaces/kube-system/pods     # 403 Forbidden
curl -sk https://localhost:6443/version                                # continua público (ok)
```

**Pegadinhas**
- Procurar só por `system:anonymous` e esquecer o **grupo** `system:unauthenticated` (ou vice-versa).
- Apagar `system:public-info-viewer`: quebra health checks/descoberta de clientes. É padrão.
- Verifique também RoleBindings (`kubectl get rolebindings -A -o wide`) numa prova real; o
  kubeadm cria `kube-public/kubeadm:bootstrap-signer-clusterinfo` para anônimos (é legítimo:
  usado pelo `kubeadm join`).

Doc: https://kubernetes.io/docs/reference/access-authn-authz/rbac/#discovery-roles

---

## Q2 (Médio) — NodePort, anonymous-auth e NodeRestriction

Edite `/etc/kubernetes/manifests/kube-apiserver.yaml` (após o backup):

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --anonymous-auth=false                    # era true
    # - --kubernetes-service-node-port=31000    # REMOVER a linha
    - --enable-admission-plugins=NodeRestriction
    ...
```

```bash
watch crictl ps                         # aguarde o apiserver novo
kubectl get svc kubernetes              # TYPE deve voltar a ClusterIP
```

O apiserver **reconcilia** o Service `kubernetes` na inicialização. Se ele continuar `NodePort`
(algumas versões não revertem o tipo), recrie-o — o próprio apiserver o recria em segundos:

```bash
kubectl delete svc kubernetes
kubectl get svc kubernetes              # recriado, ClusterIP
# ou: kubectl edit svc kubernetes  -> type: ClusterIP e remover nodePort
```

### O problema do `--anonymous-auth=false` e as probes do kubeadm

O kubeadm configura `livenessProbe`, `readinessProbe` e `startupProbe` do apiserver como
`httpGet` HTTPS em `/livez` e `/readyz` na porta 6443 — **sem credenciais**. Com
`--anonymous-auth=false`, essas requisições recebem **401**, o kubelet considera a probe falha e,
depois de alguns minutos, **reinicia o container do apiserver** (fica em loop de restarts,
dependendo da versão/configuração). Na prova o apiserver costuma subir e responder o suficiente
para a correção, mas saiba as alternativas:

**Opção recomendada (1.32+; GA na 1.34): AuthenticationConfiguration com anonymous restrito
aos endpoints de health.**

```bash
mkdir -p /etc/kubernetes/authn
cat > /etc/kubernetes/authn/authn-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1beta1   # na 1.34 também existe apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
EOF
```

No manifest: **remova** `--anonymous-auth` (não pode coexistir com `anonymous` no arquivo — o
apiserver não sobe) e adicione flag + volume:

```yaml
    - --authentication-config=/etc/kubernetes/authn/authn-config.yaml
...
    volumeMounts:
    - mountPath: /etc/kubernetes/authn
      name: authn
      readOnly: true
...
  volumes:
  - hostPath:
      path: /etc/kubernetes/authn
      type: DirectoryOrCreate
    name: authn
```

Resultado: `/livez` e `/readyz` respondem a anônimos (probes OK), qualquer outro caminho dá 401.

### Validação

```bash
curl -sk https://localhost:6443/api                     # 401 Unauthorized
kubectl get nodes                                       # admin funciona
# NodeRestriction: o kubelet NÃO pode mexer em labels node-restriction.kubernetes.io/*
kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node controlplane node-restriction.kubernetes.io/x=y
# Error ... is not allowed to modify labels: node-restriction.kubernetes.io/x
crictl ps | grep kube-apiserver                         # observe a coluna ATTEMPT (restarts)
```

**Pegadinhas**
- `--enable-admission-plugins` aceita lista separada por vírgula: **adicione** `NodeRestriction`
  sem apagar plugins que já estejam ali.
- Remover a flag NodePort e esquecer o Service (ou vice-versa: editar o Service e deixar a flag
  — o apiserver volta a criar o NodePort no próximo restart).
- `--anonymous-auth=false` + `AuthenticationConfiguration.anonymous` ao mesmo tempo = apiserver
  não sobe.

Docs:
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#anonymous-authenticator-configuration
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/ (`--kubernetes-service-node-port`)

---

## Q3 (Difícil) — apiserver totalmente inseguro

### Diagnóstico

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml /root/cks-backup/kube-apiserver.yaml.$(date +%s)
grep -nE 'anonymous|authorization-mode|admission|token-auth|basic-auth|authentication-config|insecure' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
#   - --anonymous-auth=true
#   - --token-auth-file=/etc/kubernetes/pki/auth-tokens.csv
#   - --authorization-mode=AlwaysAllow
#   (sem --enable-admission-plugins=NodeRestriction)

curl -sk https://localhost:6443/api/v1/namespaces/kube-system/secrets | head   # anônimo lê secrets!
```

### 5. A credencial de emergência: static token file

```bash
cat /etc/kubernetes/pki/auth-tokens.csv
# 9f2c...c86,ops-breakglass,1337,"system:masters"
#  token    ,usuário       ,uid ,grupos
echo ops-breakglass > /opt/course/8/q3/backdoor.txt
```

O grupo `system:masters` **ignora o RBAC** (é superusuário hard-coded), então só remover bindings
não resolveria: é preciso tirar o mecanismo de autenticação.

### Manifest corrigido (trechos)

```yaml
  - command:
    - kube-apiserver
    # - --anonymous-auth=true                                  -> remover/trocar (ver abaixo)
    # - --token-auth-file=/etc/kubernetes/pki/auth-tokens.csv  -> REMOVER
    - --authorization-mode=Node,RBAC
    - --enable-admission-plugins=NodeRestriction
    - --anonymous-auth=false
    ...
```

Para o item 1 você pode usar `--anonymous-auth=false` **ou** a `AuthenticationConfiguration`
com `anonymous.conditions` em `/livez`, `/readyz`, `/healthz` (ver Q2 — evita os restarts por
probe). As duas formas fazem `/api` responder 401.

```bash
rm /etc/kubernetes/pki/auth-tokens.csv        # opcional, depois de remover a flag
watch crictl ps
```

### 4. ClusterRoleBinding para anônimos (com nome que parece do sistema!)

```bash
kubectl get clusterrolebindings -o json | jq -r '.items[] |
  select(.subjects[]? | .name=="system:anonymous" or .name=="system:unauthenticated") | .metadata.name' | sort -u
# system:public-info-viewer    (padrão - manter)
# system:public-metrics-viewer (falso! criado pelo "teste")
kubectl delete clusterrolebinding system:public-metrics-viewer
kubectl delete clusterrole system:public-metrics          # opcional
```

> Por que o item 4 importa mesmo com `--anonymous-auth=false`? Defesa em profundidade: se alguém
> reativar o anonymous (ou usar o modo com `conditions` errado), o binding volta a dar acesso.
> E enquanto o modo era `AlwaysAllow`, o RBAC nem era consultado — ao trocar para `Node,RBAC`,
> esse binding passaria a ser a porta de entrada.

### Validação

```bash
curl -sk https://localhost:6443/api                                   # 401
curl -sk -H "Authorization: Bearer 9f2c7d41e8b34a6f0c5d2e1b7a9f3c86" \
  https://localhost:6443/api/v1/namespaces/kube-system/secrets         # 401
kubectl auth can-i list secrets -A --as qualquer-um                    # no  (sem AlwaysAllow)
kubectl auth can-i get node/controlplane --as system:node:controlplane --as-group system:nodes   # yes (Node authorizer)
kubectl --kubeconfig /etc/kubernetes/kubelet.conf label node controlplane node-restriction.kubernetes.io/x=y  # negado
kubectl get nodes; kubectl -n kube-system get pods
```

**Pegadinhas**
- `--authorization-mode=RBAC` sem `Node`: os kubelets perdem acesso a secrets/configmaps dos
  seus pods e a status do node (não há mais ClusterRoleBinding `system:nodes` por padrão). A
  ordem `Node,RBAC` é a do kubeadm e do CIS Benchmark.
- `NodeRestriction` sem o modo `Node` na autorização é inútil (e vice-versa): os dois juntos
  limitam o kubelet ao próprio node e aos pods agendados nele.
- Apagar o arquivo de tokens **sem** remover a flag `--token-auth-file`: o apiserver não sobe
  (arquivo inexistente).
- Errar indentação/hífen no YAML: o kubelet simplesmente não recria o pod — veja
  `journalctl -u kubelet | grep -i apiserver`.
- `--anonymous-auth=false` pode causar restarts pela liveness/startup probe em `/livez` (401);
  documente/considere a `AuthenticationConfiguration` com `conditions` (1.32+).
- Outras credenciais estáticas a procurar numa prova: `--token-auth-file`, kubeconfigs com
  certificados de `system:masters`, `--authentication-token-webhook-*` estranhos
  (o `--basic-auth-file` não existe mais desde a 1.19).

Docs:
- https://kubernetes.io/docs/reference/access-authn-authz/authentication/#static-token-file
- https://kubernetes.io/docs/reference/access-authn-authz/authorization/#authorization-modules
- https://kubernetes.io/docs/reference/access-authn-authz/node/
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
