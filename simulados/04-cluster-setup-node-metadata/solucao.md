# Node Metadata Protection — Soluções

> Domínio: **Cluster Setup** — "Protect node metadata and endpoints".
> Doc principal (permitida na prova): https://kubernetes.io/docs/concepts/services-networking/network-policies/

## Conceito (vale para as 3 questões)

Em nuvens (AWS, GCP, Azure, OpenStack...) toda VM tem um **metadata server** em `169.254.169.254`. Ele entrega dados da instância e, o que mais importa, **credenciais temporárias da role/service account do node** (ex.: `.../iam/security-credentials/<role>`). Se um pod comprometido (RCE, SSRF) chega nesse IP, o atacante assume a identidade do node na nuvem. Por isso a CKS cobra o bloqueio via **NetworkPolicy de egress com `ipBlock` + `except`**.

Pontos que caem na prova:

- **NetworkPolicies são aditivas (união).** Não existe "deny" explícito: um pod selecionado por qualquer policy de Egress só pode sair para o que **alguma** policy permitir. Logo, se outra policy liberar `0.0.0.0/0` sem `except`, seu `except` não adianta nada.
- `except` precisa estar **dentro** do `cidr` (ex.: `0.0.0.0/0` com `except: [169.254.169.254/32]`). Use `/32` para um único IP.
- Assim que um pod é selecionado por uma policy com `policyTypes: [Egress]`, **todo egress não listado é negado — inclusive DNS**. Se o enunciado exige DNS, libere UDP **e** TCP 53.
- `ipBlock` foi pensado para IPs **externos ao cluster**. Se `0.0.0.0/0` também cobre IPs de pods depende do CNI: no **Calico** cobre; no **Cilium** (usado no Killercoda) **não** cobre pods, CoreDNS nem nodes. Por isso, a solução portátil sempre inclui regras explícitas (`podSelector`/`namespaceSelector`) para DNS e serviços internos.
- Num item de `to:`, `namespaceSelector` + `podSelector` **no mesmo item** (sem `-` no segundo) = **E** lógico; em itens separados = **OU**.
- Todo namespace tem o label automático `kubernetes.io/metadata.name=<nome>` — use-o no `namespaceSelector`.

### Como o simulado emula a nuvem

O `setup.sh` cria no `controlplane` um network namespace `cks-meta` ligado ao host por um veth (`meta-host`), com os IPs `169.254.169.254` (metadata, servindo credenciais falsas) e `198.51.100.10` (uma "API externa"), servidos por `python3 -m http.server` (units `cks-metadata-meta`/`cks-metadata-ext`). Para o CNI esses IPs são destinos externos, como na nuvem real. Os pods do exercício rodam no `controlplane`, e o pod `cks-probe/probe` (sem policies) serve para checar que o ambiente funciona.

Teste manual de qualquer pod:

```bash
k -n <ns> exec <pod> -- wget -T2 -qO- http://169.254.169.254/latest/meta-data/iam/security-credentials/node-role
k -n <ns> exec <pod> -- wget -T2 -qO- http://198.51.100.10/
k -n <ns> exec <pod> -- nslookup kubernetes.default.svc.cluster.local
```

---

## Q1 (Fácil) — bloquear o metadata para todo o namespace

### Passo a passo

Na doc de NetworkPolicy, copie o exemplo `test-network-policy` (tem `ipBlock` com `except`) e reduza:

```yaml
# deny-metadata.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata
  namespace: cloud-app
spec:
  podSelector: {}            # todos os pods do namespace
  policyTypes:
  - Egress                   # só egress: ingress continua livre
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
```

```bash
k apply -f deny-metadata.yaml
k -n cloud-app describe netpol deny-metadata
```

### Por quê

- `podSelector: {}` seleciona todos os pods de `cloud-app`.
- Com `policyTypes: [Egress]`, tudo que não estiver em `egress` é negado; a única regra libera "a internet inteira menos o metadata".
- Não incluir `Ingress` em `policyTypes` mantém a entrada intacta. (Se você colocar `Ingress` sem regras de `ingress`, bloqueia toda a entrada — erro comum.)

### Pegadinhas

- Escrever `169.254.169.254` sem `/32` → a API rejeita (precisa ser CIDR).
- Usar `except` com CIDR fora do `cidr` → rejeitado.
- No Cilium, essa policy também corta o DNS (CoreDNS é pod, não "world"). A Q1 não exige DNS; se o enunciado exigir, veja a Q2.

### Validação

```bash
k -n cloud-app exec worker -- wget -T2 -qO- http://169.254.169.254/   # deve dar timeout
k -n cloud-app exec worker -- wget -T2 -qO- http://198.51.100.10/     # deve funcionar
```

---

## Q2 (Médio) — só o frontend, mantendo DNS e serviço interno

### Investigação

```bash
k -n payments get deploy --show-labels
k -n payments get pod --show-labels
k -n payments get deploy shop-frontend -o jsonpath='{.spec.template.metadata.labels}'; echo
```

Os pods do frontend têm `app=shop, tier=frontend`. **Pegadinha:** `app=shop` também está no backend e no api — usar só `app: shop` bloquearia o backend. O label que distingue é `tier=frontend`.

### Solução

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-deny-metadata
  namespace: payments
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  # 1) tudo externo, menos o metadata
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
  # 2) DNS (CoreDNS no kube-system) — UDP e TCP
  - to:
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
  # 3) Service api (a policy enxerga os PODS por trás do Service)
  - to:
    - podSelector:
        matchLabels:
          tier: api
    ports:
    - protocol: TCP
      port: 80
```

### Por quê

- A policy é avaliada **depois** do DNAT do Service: o destino real é o IP do pod `api`, por isso a regra usa `podSelector` dos pods do backend do Service (e a porta do container, `targetPort`).
- DNS: `kube-dns` é o label dos pods CoreDNS em clusters kubeadm. Uma alternativa aceita é `- ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]` sem `to` (DNS para qualquer destino) — mais simples, menos restritivo.
- O backend não é selecionado por nenhuma policy → continua sem restrição e acessa o metadata.

### Pegadinhas

- Esquecer TCP 53 (respostas grandes caem para TCP).
- Colocar `- podSelector` com hífen na regra de DNS → vira OU: libera kube-dns de **qualquer** namespace **ou** todos os pods do kube-system.
- Confiar que `0.0.0.0/0` libera o Service `api`: funciona no Calico, mas **não** no Cilium.

### Validação

```bash
F=$(k -n payments get pod -l tier=frontend -o name | head -1)
B=$(k -n payments get pod -l tier=backend -o name | head -1)
k -n payments exec $F -- wget -T2 -qO- http://169.254.169.254/            # timeout
k -n payments exec $F -- wget -T2 -qO- http://api.payments.svc.cluster.local  # OK
k -n payments exec $F -- wget -T2 -qO- http://198.51.100.10/              # OK
k -n payments exec $B -- wget -T2 -qO- http://169.254.169.254/            # OK
```

---

## Q3 (Difícil) — exceção por label + troubleshooting de policies existentes

### Investigação

```bash
k -n ml-platform get netpol
k -n ml-platform get netpol -o yaml
k -n ml-platform get pod --show-labels
k -n storage get netpol model-store-ingress -o yaml
k get ns ml-platform kube-system --show-labels
```

Problemas encontrados:

| # | Problema | Efeito |
|---|----------|--------|
| 1 | `legacy-egress` libera `0.0.0.0/0` **sem `except`** para todos os pods | metadata aberto para todos (policies são aditivas: nenhum `except` em outra policy vai fechar isso) |
| 2 | `allow-dns` usa `namespaceSelector: name=kube-system` — esse label não existe | DNS quebrado (e só libera UDP) |
| 3 | Nenhuma policy libera egress para os pods do `model-store` (no Cilium `0.0.0.0/0` não cobre pods) | `model-store` inacessível |
| 4 | `storage/model-store-ingress` só aceita entrada de namespaces com `team=ml`, e `ml-platform` não tem esse label | `model-store` inacessível mesmo com egress liberado |
| 5 | O pod `notebook` já tem `role=metadata-accessor`; o `cloud-sync` não tem | exceção aplicada ao pod errado |

`default-deny-egress` deve ficar como está — não é ela que causa problema (é só a base de "nega tudo"; as outras liberam).

### 1) Corrigir `legacy-egress` (adicionar o `except`)

```bash
k -n ml-platform edit netpol legacy-egress
```

```yaml
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
```

(Também vale apagar `legacy-egress` e criar outra policy equivalente.)

### 2) Corrigir `allow-dns`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: ml-platform
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
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

### 3) Liberar egress para o model-store + 4) label no namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-model-store
  namespace: ml-platform
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: storage
      podSelector:
        matchLabels:
          app: model-store
    ports:
    - protocol: TCP
      port: 80
```

```bash
# o lado de INGRESS (namespace storage) exige team=ml no namespace de origem
k label ns ml-platform team=ml
```

Lembre: para o tráfego passar entre namespaces com policies dos dois lados, é preciso **egress liberado na origem E ingress liberado no destino**.

### 5) A exceção do metadata

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-metadata-accessor
  namespace: ml-platform
spec:
  podSelector:
    matchLabels:
      role: metadata-accessor
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32
    ports:
    - protocol: TCP
      port: 80
```

Labels — no **template** do Deployment (para sobreviver à recriação dos pods) e removendo do pod errado:

```bash
k -n ml-platform patch deploy cloud-sync -p '{"spec":{"template":{"metadata":{"labels":{"role":"metadata-accessor"}}}}}'
k -n ml-platform rollout status deploy cloud-sync
k -n ml-platform label pod notebook role-
k -n ml-platform get pod --show-labels
```

Pegadinha: `k label deploy cloud-sync role=...` coloca o label só no **objeto Deployment**, não nos pods. E `k label pod <cloud-sync-xxx> ...` some quando o pod é recriado. Não adicione o label ao `selector` do Deployment (é imutável).

### Por quê funciona

- Pods sem o label: união de `legacy-egress` (tudo externo menos metadata) + DNS + model-store → metadata negado.
- Pods do `cloud-sync`: mesma união + `allow-metadata-accessor` (169.254.169.254/32:80) → metadata permitido. É a forma correta de "exceção": como não há deny explícito, a exceção é **outra policy aditiva** para o grupo privilegiado.

### Validação

```bash
for app in cloud-sync trainer notebook; do
  P=$(k -n ml-platform get pod -l app=$app -o name | head -1)
  echo "== $app"
  k -n ml-platform exec $P -- wget -T2 -qO- http://169.254.169.254/ >/dev/null 2>&1 && echo "metadata: SIM" || echo "metadata: NAO"
  k -n ml-platform exec $P -- wget -T2 -qO- http://model-store.storage.svc.cluster.local >/dev/null 2>&1 && echo "model-store: OK" || echo "model-store: FALHA"
  k -n ml-platform exec $P -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && echo "dns: OK" || echo "dns: FALHA"
done
```

Esperado: só `cloud-sync` com `metadata: SIM`; todos com model-store e DNS OK.

---

## Dicas de velocidade

- Não existe `kubectl create networkpolicy`: copie o YAML da doc (`Concepts > Services, Load Balancing, and Networking > Network Policies`) — o exemplo `test-network-policy` tem `ipBlock`, `except`, `namespaceSelector`, `podSelector` e `ports` de uma vez.
- `k get netpol -A` primeiro: em questões "difíceis" quase sempre há uma policy existente atrapalhando.
- `k describe netpol <nome>` mostra a policy em texto legível (bom para conferir E/OU).
- Teste com `wget -T2` (busybox) ou `curl -m2` para não esperar timeouts longos.
