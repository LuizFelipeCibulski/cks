# Soluções — Pod-to-Pod com Cilium (CiliumNetworkPolicy, L7, deny, WireGuard, mutual auth)

> Conceito geral: o currículo da CKS fala em *"Implement Pod-to-Pod encryption (Cilium, Istio)"*. No Killercoda o CNI é o Cilium, então você precisa saber:
> (1) escrever `CiliumNetworkPolicy` (L3/L4/L7 e deny), (2) ligar a **criptografia transparente** (WireGuard ou IPsec) e
> (3) conhecer a **mutual authentication** (`authentication.mode: required`).
> Referência rápida: `kubectl explain ciliumnetworkpolicy.spec --recursive | less` funciona e é ótimo na prova.

---

## Q1 (Fácil) — CiliumNetworkPolicy L3/L4

### Passo a passo

```bash
k -n team-blue get pod --show-labels
k -n team-green get pod --show-labels
```

```yaml
# /root/backend-ingress.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-ingress
  namespace: team-blue
spec:
  endpointSelector:          # a quem a política se aplica
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:           # de onde pode vir
    - matchLabels:
        app: frontend
    toPorts:                 # em qual porta
    - ports:
      - port: "80"
        protocol: TCP
```

```bash
k apply -f /root/backend-ingress.yaml
k get cnp -n team-blue
```

### Por quê
- Assim que **qualquer** regra de `ingress` seleciona um endpoint, o Cilium coloca esse endpoint em **default deny** para ingress: só passa o que foi explicitamente permitido.
- Em uma `CiliumNetworkPolicy` (namespaced), `fromEndpoints` **sem** label de namespace casa apenas com Pods do **mesmo namespace** da política. Por isso o `frontend` do `team-green` fica bloqueado automaticamente. Para liberar outro namespace você usaria a label `k8s:io.kubernetes.pod.namespace: team-green` no `matchLabels`.
- Diferença para a NetworkPolicy padrão: o seletor do alvo é `endpointSelector` (e não `podSelector`), e as portas são strings dentro de `toPorts[].ports[]`.

### Pegadinhas
- `port: 80` sem aspas funciona na maioria das versões, mas o schema define string — use `"80"`.
- Esquecer `protocol` não quebra (default ANY), mas a questão pede TCP.
- Não misture: `fromEndpoints` e `toPorts` precisam estar **no mesmo item** da lista `ingress` (mesmo `-`), senão viram duas regras independentes (OR).

### Validação manual
```bash
k -n team-blue exec frontend -- wget -qO- -T2 backend        # OK
k -n team-blue exec other -- wget -qO- -T2 backend           # timeout
k -n team-green exec frontend -- wget -qO- -T2 backend.team-blue   # timeout
```

Doc: https://docs.cilium.io/en/stable/security/policy/language/#layer-3-examples

---

## Q2 (Médio) — L7 HTTP + deny policy

### 1) Política L7 `api-l7`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7
  namespace: shop
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/public.*"     # path é EXPRESSÃO REGULAR (POSIX), não prefixo
```

### 2) Deny de egress `client-deny-world`

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: client-deny-world
  namespace: shop
spec:
  endpointSelector:
    matchLabels:
      app: client
  egressDeny:
  - toEntities:
    - world
  egress:              # necessário: sem isso o endpoint entra em default-deny de egress
  - toEntities:
    - all
```

Alternativa (Cilium ≥ 1.15) para não precisar do allow-all:
```yaml
spec:
  enableDefaultDeny:
    egress: false
  endpointSelector: {matchLabels: {app: client}}
  egressDeny:
  - toEntities: [world]
```

```bash
k apply -f api-l7.yaml -f client-deny-world.yaml
```

### Por quê
- Quando existe `rules.http`, o tráfego dessa porta é redirecionado para o **proxy Envoy** do Cilium, que inspeciona método/caminho. O que não casar recebe **HTTP 403 "Access denied"** (não é timeout: a conexão TCP é aceita, quem nega é o proxy).
- `path` é regex: `/public` sozinho casaria só exatamente `/public`. Use `/public.*` (ou `/public/.*`).
- Regras **deny** (`ingressDeny`/`egressDeny`) têm **precedência** sobre qualquer allow. Mas uma política com regras de egress (inclusive deny) coloca o endpoint em default-deny — por isso o `egress: toEntities: [all]` (padrão do exemplo "external-lockdown" da doc). Sem ele o `client` perde o DNS e o acesso à `api`.
- Entidades úteis: `world` (fora do cluster), `cluster`, `host`, `remote-node`, `kube-apiserver`, `all`.

### Pegadinhas
- Deny **não** suporta regras L7.
- Testar `/private/` dando 403 (L7) vs timeout (L3/L4) mostra se a regra L7 está ativa.
- `intruder` fica bloqueado porque só `app=client` está em `fromEndpoints`.

### Validação manual
```bash
k -n shop exec client -- wget -qO- -T3 http://api/public/          # catalogo publico
k -n shop exec client -- wget -qO- -T3 http://api/private/         # 403 Forbidden
k -n shop exec client -- wget -qO- -T3 --post-data=x http://api/public/   # 403
k -n shop exec intruder -- wget -qO- -T3 http://api/public/        # timeout
k -n shop exec client -- wget -T3 -O- http://1.1.1.1               # timeout (world negado)
```
Opcional: `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg policy get` / `hubble observe` se disponível.

Docs: https://docs.cilium.io/en/stable/security/http/ e https://docs.cilium.io/en/stable/security/policy/language/#deny-policies

---

## Q3 (Difícil) — WireGuard + política + mutual auth

### 1) Habilitar WireGuard

Opção A — cilium CLI (mais rápida; edita o ConfigMap e reinicia os agentes):
```bash
cilium config view | grep -i wireguard
cilium config set enable-wireguard true
kubectl -n kube-system rollout status ds/cilium
cilium status --wait | grep -i encryption      # Encryption: Wireguard
```

Opção B — manual:
```bash
kubectl -n kube-system edit cm cilium-config
#   data:
#     enable-wireguard: "true"
kubectl -n kube-system rollout restart ds/cilium
kubectl -n kube-system rollout status ds/cilium
```

Se o Cilium foi instalado via Helm, o equivalente "oficial" é:
`helm upgrade cilium cilium/cilium -n kube-system --reuse-values --set encryption.enabled=true --set encryption.type=wireguard`.

**Pegadinha clássica:** editar o ConfigMap e **não reiniciar** os pods do Cilium — o agente só lê a config na inicialização. O ConfigMap diz `true` mas `encrypt status` continua `Disabled`.

### 2) Status do agente no controlplane

```bash
kubectl -n kube-system get pod -l k8s-app=cilium -o wide        # ache o pod do node controlplane
P=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=controlplane -o name)
kubectl -n kube-system exec $P -c cilium-agent -- cilium-dbg encrypt status | tee /opt/course/17/encrypt-status.txt
# Encryption: Wireguard
# Interface: cilium_wg0
#         Public key: ...
#         Number of peers: 1
```
Pegadinha: `kubectl exec ds/cilium` escolhe um pod **qualquer** do DaemonSet, não necessariamente o do controlplane. Em versões antigas o binário dentro do pod chama `cilium` em vez de `cilium-dbg`.

No host: `ip link show cilium_wg0` e `wg show` (se `wireguard-tools` estiver instalado). Para "provar" a criptografia: `tcpdump -ni cilium_wg0` enquanto faz requests entre pods de nós diferentes.

### 3) Política da API de pagamentos

Primeiro, investigue o que já existe:
```bash
k -n secure-payments get cnp,netpol
k -n secure-payments get cnp payment-api-monitoring -o yaml
```
A política legada `payment-api-monitoring` permite ingress de `fromEntities: [cluster]` — ou seja, **qualquer Pod do cluster**. Políticas Cilium são **aditivas** (união dos allows): enquanto ela existir, criar uma política restritiva não bloqueia o `attacker`. Remova-a:
```bash
k -n secure-payments delete cnp payment-api-monitoring
```

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: payment-api-ingress
  namespace: secure-payments
spec:
  endpointSelector:
    matchLabels:
      app: payment-api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: payment-client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

Validação:
```bash
k -n secure-payments exec payment-client -- wget -qO- -T3 payment-api:8080 | head -3   # OK
k -n secure-payments exec attacker -- wget -qO- -T3 payment-api:8080                   # timeout
```

### 4) Manifesto de mutual authentication (não aplicar)

```yaml
# /opt/course/17/mutual-auth.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: payment-api-mutual-auth
  namespace: secure-payments
spec:
  endpointSelector:
    matchLabels:
      app: payment-api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: payment-client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
    authentication:
      mode: "required"
```
```bash
kubectl apply --dry-run=server -f /opt/course/17/mutual-auth.yaml    # valida contra o CRD sem criar
```

### Por quê
- **WireGuard** (ou IPsec) no Cilium criptografa o tráfego Pod-to-Pod **entre nós** de forma transparente — as aplicações não mudam. Cada nó gera um par de chaves e publica a pública na anotação/CRD `CiliumNode`; a interface `cilium_wg0` faz o túnel. Tráfego entre Pods do **mesmo nó** não sai do host e não é criptografado (a menos que se use `encrypt-node`/node-to-node).
- **Mutual authentication** (`authentication.mode: required`) faz o Cilium exigir que as duas identidades se autentiquem (mTLS com identidades SPIFFE emitidas pelo **SPIRE**) antes de permitir o fluxo. Sem `authentication.mutual.spire.enabled=true` e o SPIRE instalado, os pacotes ficam marcados como "auth required" e são **descartados** — por isso não aplicar.
- Comparação com Istio: no Istio o mTLS é feito pelos sidecars/ztunnel (`PeerAuthentication` com `mtls.mode: STRICT`). No Cilium, a criptografia é no datapath (WireGuard/IPsec) e a autenticação mútua é separada.

### Pegadinhas
- `authentication` fica **no mesmo nível** de `fromEndpoints`/`toPorts` dentro do item de `ingress`, não dentro de `toPorts`.
- `--dry-run=client` não valida o schema do CRD; use `--dry-run=server`.
- Em clusters sem node01 o tráfego fica todo no mesmo nó — o `encrypt status` mostra 0 peers, mas a configuração continua correta.

Docs:
- https://docs.cilium.io/en/stable/security/network/encryption-wireguard/
- https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/
