# Supply Chain Security — Soluções

---

## Q1 (Fácil) — Imagens por digest

### Por quê
Uma tag (`nginx:1.27-alpine`) é só um ponteiro mutável: quem tem acesso de push ao registry pode apontá-la para outro conteúdo. O **digest** (`sha256:...`) é o hash do manifest da imagem — se o conteúdo mudar, o digest muda. Referenciar por digest garante que o node vai baixar exatamente aquele conteúdo (e o kubelet/containerd valida o hash no pull).

### Passo a passo

1. Descobrir os digests que estão rodando agora (campo `imageID` do status do Pod):

```bash
k -n supply-chain get pod -l app=payment-api \
  -o jsonpath='{range .items[0].status.containerStatuses[*]}{.name}{"\t"}{.imageID}{"\n"}{end}'
# api        docker.io/library/nginx@sha256:aaaa...
# log-agent  docker.io/library/busybox@sha256:bbbb...
```

Alternativas: `k describe pod <pod> | grep "Image ID"` ou, no node, `crictl images --digests` / `crictl inspecti nginx:1.27-alpine`.

2. Atualizar o Deployment (imperativo é o mais rápido):

```bash
k -n supply-chain set image deploy/payment-api \
  api=docker.io/library/nginx@sha256:aaaa... \
  log-agent=docker.io/library/busybox@sha256:bbbb...
```

ou `k -n supply-chain edit deploy payment-api` e trocar:

```yaml
      containers:
      - name: api
        image: docker.io/library/nginx@sha256:aaaa...      # sem ":1.27-alpine"
      - name: log-agent
        image: docker.io/library/busybox@sha256:bbbb...
```

`nginx@sha256:...` (sem o prefixo `docker.io/library/`) também é válido.

3. Validar:

```bash
k -n supply-chain rollout status deploy/payment-api
k -n supply-chain get pod -l app=payment-api -o jsonpath='{.items[*].spec.containers[*].image}'
```

### Pegadinhas
- `imageID` às vezes aparece como `docker.io/library/nginx@sha256:...` — copie **só** a parte `@sha256:...` e mantenha o repositório.
- `nginx:1.27-alpine@sha256:...` é aceito pelo Kubernetes (a tag é ignorada), mas a tarefa pede **sem tag** — e na prova, siga literalmente.
- Não use o "Image ID" do `crictl images` (coluna IMAGE ID é o ID da config, não o digest do repositório). Use `crictl images --digests` (coluna DIGEST) ou o `imageID` do Pod.

Docs: https://kubernetes.io/docs/concepts/containers/images/#image-names

---

## Q2 (Médio) — ValidatingAdmissionPolicy para registries confiáveis

### Por quê
`ValidatingAdmissionPolicy` (GA desde 1.30) executa regras CEL **dentro** do kube-apiserver, sem webhook externo (sem latência de rede, sem ponto de falha extra). A policy define a regra; o binding define **onde** e **como** (Deny/Warn/Audit) ela é aplicada. Sem binding, a policy não faz nada.

### Passo a passo

Copie o exemplo da doc (página "Validating Admission Policy") e adapte:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: trusted-registries
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups:   [""]
      apiVersions: ["v1"]
      operations:  ["CREATE", "UPDATE"]
      resources:   ["pods"]
  variables:
  - name: allContainers
    expression: "object.spec.containers + (has(object.spec.initContainers) ? object.spec.initContainers : [])"
  validations:
  - expression: >-
      variables.allContainers.all(c,
        c.image.startsWith('registry.k8s.io/') ||
        c.image.startsWith('registry.cks.local:5000/'))
    message: "image registry not trusted"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: trusted-registries-binding
spec:
  policyName: trusted-registries
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        registry-policy: enforced
```

```bash
k apply -f vap.yaml
k label ns team-blue registry-policy=enforced
```

Versão sem `variables` (equivalente):

```yaml
  validations:
  - expression: "object.spec.containers.all(c, c.image.startsWith('registry.k8s.io/') || c.image.startsWith('registry.cks.local:5000/'))"
    message: "image registry not trusted"
  - expression: "!has(object.spec.initContainers) || object.spec.initContainers.all(c, c.image.startsWith('registry.k8s.io/') || c.image.startsWith('registry.cks.local:5000/'))"
    message: "image registry not trusted"
```

### Violações existentes

```bash
k -n team-blue get pod -o custom-columns='NAME:.metadata.name,INIT:.spec.initContainers[*].image,IMAGES:.spec.containers[*].image'
```

Violam: `web-frontend` (nginx Docker Hub), `cache` (initContainer busybox), `legacy` (docker.io), `metrics-proxy` (`registry.k8s.io.mirror-cdn.com/...` — **não** começa com `registry.k8s.io/`). Não violam: `metrics`, `probe`.

```bash
mkdir -p /opt/course/21/q2
printf "cache\nlegacy\nmetrics-proxy\nweb-frontend\n" > /opt/course/21/q2/violations.txt
```

### Testar manualmente
`--dry-run=server` passa pela cadeia de admissão:

```bash
k -n team-blue run t --image=nginx:1.27-alpine --dry-run=server        # negado
k -n team-blue run t --image=registry.k8s.io/pause:3.10 --dry-run=server # permitido
k -n team-green run t --image=nginx:1.27-alpine --dry-run=server       # permitido
```

### Pegadinhas
- Prefixo **com barra**: `startsWith('registry.k8s.io')` aceitaria `registry.k8s.io.evil.com/...`.
- Esquecer `initContainers` (e, se a prova pedir, `ephemeralContainers`).
- `has(object.spec.initContainers)` é necessário: o campo pode não existir.
- O label pode ir no `namespaceSelector` do binding (pedido aqui) ou na `matchConstraints` da policy — mas confira o que o enunciado pede.
- `validationActions: [Warn]` ou `[Audit]` não bloqueiam nada.
- Policies demoram ~1s para serem compiladas/aplicadas; `k describe validatingadmissionpolicy` mostra erros de type-check em `status.typeChecking`.

Docs: https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/

---

## Q3 (Difícil) — Completar o ImagePolicyWebhook

### Por quê
O `ImagePolicyWebhook` envia um `ImageReview` para um serviço externo a cada criação de Pod; o serviço decide se as imagens são permitidas (ex.: só imagens assinadas/escaneadas). `defaultAllow: false` faz o plugin **falhar fechado**: se o backend não responde, o Pod é negado — o comportamento seguro.

### Erros plantados
1. `kubeConfigFile` aponta para `kubeconfig.yaml`, mas o arquivo se chama `kubeconf`.
2. `allowTTL: 50` e `defaultAllow: true`.
3. `server:` do kubeconf aponta para outro endereço.
4. No manifest, o volume `policywebhook` foi declarado, mas **não há volumeMount** nem as flags.

### Passo a passo

```bash
cd /etc/kubernetes/policywebhook
ls                       # admission_config.json  kubeconf  *.pem
vim admission_config.json
```

```json
{
   "apiVersion": "apiserver.config.k8s.io/v1",
   "kind": "AdmissionConfiguration",
   "plugins": [
      {
         "name": "ImagePolicyWebhook",
         "configuration": {
            "imagePolicy": {
               "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconf",
               "allowTTL": 100,
               "denyTTL": 50,
               "retryBackoff": 500,
               "defaultAllow": false
            }
         }
      }
   ]
}
```

```bash
vim kubeconf      # clusters[0].cluster.server: https://localhost:1234
```

Manifest do apiserver (**sempre faça backup fora de /etc/kubernetes/manifests**):

```bash
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.bak
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/policywebhook/admission_config.json
    ...
    volumeMounts:
    - mountPath: /etc/kubernetes/policywebhook
      name: policywebhook
      readOnly: true
    ...
  volumes:
  - hostPath:                      # já existia (criado pelo colega)
      path: /etc/kubernetes/policywebhook
      type: DirectoryOrCreate
    name: policywebhook
```

Aguarde o restart:

```bash
watch crictl ps --name kube-apiserver
k get --raw=/readyz
```

Se não subir: `crictl ps -a | grep apiserver`, `crictl logs <id>` ou `tail /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log`. Erros típicos:
- `no such file or directory` → volume não montado ou path errado no JSON.
- `couldn't parse` → JSON inválido (vírgula sobrando).
- `--enable-admission-plugins` duplicado: o apiserver usa só a última ocorrência.

### Validar

```bash
k run test --image=nginx
# Error from server (Forbidden): pods "test" is forbidden: Post "https://localhost:1234/?timeout=30s": dial tcp 127.0.0.1:1234: connect: connection refused
```

### Restaurar depois do exercício

```bash
cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Pegadinhas
- O path na flag `--admission-control-config-file` é o path **dentro do container**; o arquivo precisa estar montado.
- Os `.pem` referenciados no kubeconf também precisam estar acessíveis — por isso monte o **diretório**.
- `defaultAllow: false` + backend inexistente = **nenhum** Pod novo (inclui Pods de DaemonSets do sistema). Mirror pods dos static pods podem sumir do `kubectl get pods` — o container continua rodando (veja com `crictl`).
- O nome do plugin é case-sensitive: `ImagePolicyWebhook`.

Docs: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook
