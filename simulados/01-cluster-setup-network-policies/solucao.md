# Network Policies — Soluções

> Doc base para copiar exemplos: https://kubernetes.io/docs/concepts/services-networking/network-policies/
> (seções "The NetworkPolicy resource" e "Default policies" têm YAMLs prontos para colar).

## Conceitos que caem sempre

- **NetworkPolicy é allow-list e aditiva.** Um Pod só fica "isolado" para uma direção (Ingress/Egress) quando alguma política o seleciona com aquele `policyType`. A partir daí, só passa o que alguma política permitir — a **união** de todas. Não existe regra "deny" explícita: para bloquear algo que outra política libera, você precisa **editar/apagar** a política permissiva.
- `podSelector: {}` = todos os Pods do namespace da política.
- `policyTypes` sem `ingress:`/`egress:` = nega tudo naquela direção.
- **AND vs OR** no `from`/`to`:
  ```yaml
  # AND — um único item da lista com os dois seletores (Pod X *no* namespace Y)
  - from:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: orders}}
      podSelector: {matchLabels: {app: api}}
  # OR — dois itens (qualquer Pod do ns Y OU Pod X do *mesmo* namespace da política)
  - from:
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: orders}}
    - podSelector: {matchLabels: {app: api}}
  ```
  O hífen faz toda a diferença.
- Todo namespace tem automaticamente o label `kubernetes.io/metadata.name=<nome>` — use-o no `namespaceSelector` em vez de inventar labels.
- **Bloqueou Egress? Libere o DNS** (UDP **e** TCP 53 para o kube-dns), senão nada resolve por nome.
- `kubectl` não gera NetworkPolicy imperativamente: copie da doc ou mantenha um "esqueleto" na memória.

Testes manuais úteis:

```bash
k -n NS exec POD -- wget -qO- -T2 http://ALVO          # HTTP
k -n NS exec POD -- nslookup kubernetes.default.svc.cluster.local   # DNS
k -n NS get netpol; k -n NS describe netpol NOME       # describe mostra AND/OR de forma legível
```

---

## Q1 (Fácil) — default deny

### Passo a passo

```bash
mkdir -p /opt/course/netpol/q1
cat > /opt/course/netpol/q1/default-deny.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: restricted
spec:
  podSelector: {}        # todos os Pods do namespace
  policyTypes:
  - Ingress              # sem bloco ingress: => nada entra
  - Egress               # sem bloco egress:  => nada sai
EOF
kubectl apply -f /opt/course/netpol/q1/default-deny.yaml
```

### Por quê

O modelo de rede do Kubernetes é "flat": por padrão todo Pod fala com todo Pod. Um default deny por namespace é a base do princípio de menor privilégio — depois você libera só os fluxos necessários com políticas adicionais.

### Validação manual

```bash
k -n restricted describe netpol default-deny
IP=$(k -n restricted get pod app1 -o jsonpath='{.status.podIP}')
k -n cks-probe exec probe -- wget -qO- -T2 http://$IP     # deve dar timeout
k -n restricted exec app1 -- wget -qO- -T2 http://$(k -n cks-probe get pod probe -o jsonpath='{.status.podIP}')  # timeout
```

### Pegadinhas

- Esquecer `Egress` em `policyTypes` → só bloqueia a entrada. Se você omitir `policyTypes`, o Kubernetes assume `Ingress` (e `Egress` apenas se existir um bloco `egress`).
- Colocar `ingress: [{}]` → isso **libera** tudo (uma regra vazia casa com qualquer origem). Deny = sem regra.
- Esquecer o `namespace:` no metadata e criar a política no `default`.

---

## Q2 (Médio) — namespaceSelector + podSelector e egress com DNS

### 1. `gateway-ingress` (namespace `payments`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway-ingress
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: gateway          # só o gateway; ledger fica de fora
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:    # MESMO item da lista => AND
        matchLabels:
          kubernetes.io/metadata.name: orders
      podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 80
```

### 2. `api-egress` (namespace `orders`)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: orders
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: payments
      podSelector:
        matchLabels:
          app: gateway
    ports:
    - protocol: TCP
      port: 80
  - to:                       # DNS
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

```bash
k apply -f gateway-ingress.yaml -f api-egress.yaml
```

### Por quê

- O `sandbox/api` tem o mesmo label `app=api`: se você usar só `podSelector` (sem namespaceSelector), a regra vale apenas para Pods do **mesmo namespace** da política (payments) — ninguém de `orders` entraria. Se separar os dois seletores em itens diferentes (OR), qualquer Pod de `orders` (inclusive o `worker`) entra. Só o AND atende.
- A política de egress referencia o Pod de destino, e a de ingress referencia a origem: para o fluxo `api → gateway` funcionar, **as duas pontas** precisam permitir (egress no `orders`, ingress no `payments`).
- Na porta da regra de egress use a **porta do Pod/container** (targetPort), não a do Service. Aqui são iguais (80), mas na Q3 isso importa se o Service mapear portas diferentes.

### Validação manual

```bash
k -n orders exec api -- wget -qO- -T2 http://gateway.payments.svc.cluster.local   # payments/gateway
k -n orders exec api -- wget -qO- -T2 http://ledger.payments.svc.cluster.local    # timeout
k -n orders exec worker -- wget -qO- -T2 http://gateway.payments.svc.cluster.local # timeout
k -n sandbox exec api -- wget -qO- -T2 http://$(k -n payments get pod gateway -o jsonpath='{.status.podIP}')  # timeout
```

### Pegadinhas

- DNS só com UDP: respostas grandes e alguns resolvers usam TCP; a prova costuma pedir os dois.
- `matchlabels` (minúsculo) → o `kubectl apply` rejeita com erro de campo desconhecido (strict decoding). Leia o erro!
- Se `wget` por **nome** falha mas por **IP** funciona, o problema é DNS.

---

## Q3 (Difícil) — 3 camadas, políticas herdadas, DNS e ipBlock

### Diagnóstico das políticas existentes

```bash
k get netpol -A
k -n frontend describe netpol default-deny     # só Ingress -> falta Egress
k -n backend describe netpol allow-frontend    # namespaceSelector name=frontend
k get ns frontend --show-labels                # não existe label "name" -> a regra não casa nada
k -n database describe netpol allow-all-legacy # ingress: [{}] -> libera TUDO (políticas somam!)
```

Três problemas plantados:
1. `frontend/default-deny` não bloqueia Egress.
2. `backend/allow-frontend` usa um label de namespace inexistente (`name: frontend`), então web nunca chega na api. Corrija para `kubernetes.io/metadata.name: frontend` (não altere labels de namespace — era proibido).
3. `database/allow-all-legacy` libera todo o ingress e anula o default deny (as políticas são aditivas). **Apague-a.**

```bash
k -n database delete netpol allow-all-legacy
```

### Manifesto completo

```yaml
# ---------- default deny + DNS nos 3 namespaces ----------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: frontend
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: backend
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# database/default-deny já estava correta (Ingress + Egress)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: frontend
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - {protocol: UDP, port: 53}
    - {protocol: TCP, port: 53}
---
# (repita allow-dns trocando namespace: backend e namespace: database)
# ---------- frontend ----------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes: [Ingress, Egress]
  ingress:
  - ports:                    # sem "from" => qualquer origem
    - {protocol: TCP, port: 80}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend
      podSelector:
        matchLabels:
          app: api
    ports:
    - {protocol: TCP, port: 8080}
---
# ---------- backend ----------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend        # política herdada, corrigida
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: frontend
      podSelector:
        matchLabels:
          app: web
    ports:
    - {protocol: TCP, port: 8080}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Egress]
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: database
      podSelector:
        matchLabels:
          app: db
    ports:
    - {protocol: TCP, port: 5432}
  - to:
    - ipBlock:
        cidr: 1.1.1.1/32
    ports:
    - {protocol: TCP, port: 443}
---
# ---------- database ----------
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress
  namespace: database
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: backend
      podSelector:
        matchLabels:
          app: api
    ports:
    - {protocol: TCP, port: 5432}
```

Dica de velocidade: escreva o `allow-dns` uma vez e aplique nos três namespaces com um loop:

```bash
for ns in frontend backend database; do
  sed "s/namespace: frontend/namespace: $ns/" allow-dns.yaml | k apply -f -
done
```

### Por quê

- Microsegmentação: cada camada só aceita da camada imediatamente anterior e só fala com a seguinte. Um atacante que comprometa o `web` não consegue ir direto ao banco; um Pod qualquer (`batch`, `debug`) comprometido também não.
- Para cada fluxo entre namespaces isolados você precisa de **duas regras**: egress na origem e ingress no destino.
- `ipBlock` é para IPs **externos** ao cluster. Não use `ipBlock` para Pods (IPs de Pod mudam e, no Cilium, CIDR policies não casam com endpoints do cluster).

### Validação manual

```bash
k -n frontend exec deploy/web -- wget -qO- -T3 http://api.backend.svc.cluster.local:8080   # backend/api
k -n backend  exec deploy/api -- wget -qO- -T3 http://db.database.svc.cluster.local:5432   # database/db
k -n frontend exec deploy/web -- wget -qO- -T3 http://db.database.svc.cluster.local:5432   # timeout
k -n backend  exec deploy/batch -- nslookup kubernetes.default.svc.cluster.local           # resolve
```

### Pegadinhas

- **Ingress "de qualquer origem"**: use uma regra sem `from` (só `ports`). `ipBlock: 0.0.0.0/0` **não** representa Pods do cluster em vários CNIs (no Cilium, CIDR casa só com tráfego "world"), então Pods de outros namespaces seriam bloqueados.
- Esquecer o DNS em `database`/`backend` → `api` não resolve `db.database...` e parece que o problema é a política do banco.
- Deixar a `allow-all-legacy`: com ela, qualquer Pod chega no `db`, mesmo com o default deny — políticas nunca "subtraem".
- Usar a porta do Service em vez da do container: aqui coincidem, mas NetworkPolicy avalia a porta **de destino do Pod** (após o DNAT do Service).
- Criar a política "web" com `podSelector: {}` no egress → o `debug` também passaria a falar com a api (só é barrado porque o ingress da api exige `app=web`). Seja preciso no seletor.

Docs: https://kubernetes.io/docs/concepts/services-networking/network-policies/ · https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
