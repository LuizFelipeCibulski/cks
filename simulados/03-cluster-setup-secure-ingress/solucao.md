# Secure Ingress — Soluções

> Referências principais:
> - https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
> - https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
> - https://kubernetes.github.io/ingress-nginx/user-guide/tls/

## Conceitos que valem para as 3 questões

- **Terminação TLS no Ingress**: o controller (ingress-nginx) decifra o tráfego usando a Secret referenciada em `spec.tls[].secretName`. A Secret precisa ser do tipo `kubernetes.io/tls` (chaves `tls.crt` e `tls.key`) e estar **no mesmo namespace do Ingress**. Não existe referência entre namespaces.
- **Fake Certificate**: quando o ingress-nginx não encontra a Secret, ou o certificado não cobre o host pedido via SNI, ele serve o certificado padrão *Kubernetes Ingress Controller Fake Certificate*. Na prova, se você ver esse certificado, o problema é Secret inexistente, Secret em outro namespace, host fora do `tls.hosts` ou certificado sem SAN para o host.
- **SAN (Subject Alternative Name)**: clientes modernos ignoram o CN e validam só o SAN. Gere sempre com `-addext "subjectAltName=DNS:..."`.
- **Redirecionamento**: no ingress-nginx, se o Ingress tem TLS válido, `ssl-redirect` vale `true` por padrão e o HTTP recebe **308** para HTTPS. A annotation `nginx.ingress.kubernetes.io/ssl-redirect: "false"` desliga isso, e `nginx.ingress.kubernetes.io/force-ssl-redirect: "true"` força o redirect mesmo sem TLS no Ingress.
- **Testar sem DNS**: use `curl --resolve <host>:<porta>:<ip>`. Ele envia o SNI e o Host corretos sem precisar mexer no `/etc/hosts`.

Para descobrir as portas e o IP:

```bash
k -n ingress-nginx get svc ingress-nginx-controller
#   80:3xxxx/TCP,443:3yyyy/TCP   -> 3xxxx = HTTP, 3yyyy = HTTPS
HTTPS=$(k -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
HTTP=$(k -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
IP=$(k get node controlplane -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
```

---

## Q1 (Fácil): Secret TLS + TLS no Ingress existente

### 1. Criar a Secret TLS (imperativo, que é o mais rápido)

```bash
k -n secure-web create secret tls web-tls \
  --cert=/opt/course/ingress1/tls.crt \
  --key=/opt/course/ingress1/tls.key
```

### 2. Adicionar `spec.tls` ao Ingress

```bash
k -n secure-web edit ingress web
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: secure-web
spec:
  ingressClassName: nginx
  tls:                       # <- adicionado
  - hosts:
    - web.cks.local
    secretName: web-tls
  rules:
  - host: web.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

Se preferir não usar o editor, um patch resolve:

```bash
k -n secure-web patch ingress web --type=merge \
  -p '{"spec":{"tls":[{"hosts":["web.cks.local"],"secretName":"web-tls"}]}}'
```

### Validação manual

```bash
curl -k --resolve web.cks.local:$HTTPS:$IP https://web.cks.local:$HTTPS/
# backend=web

curl -kv --resolve web.cks.local:$HTTPS:$IP https://web.cks.local:$HTTPS/ 2>&1 | grep -E 'subject|issuer'
# subject: CN=web.cks.local; O=cks   (não pode aparecer "Fake Certificate")
```

### Pegadinhas

- O host em `tls.hosts` precisa ser **idêntico** ao `rules[].host`.
- `kubectl create secret generic` com as chaves erradas (`cert`/`key`) não serve. Use `create secret tls`, que já cria o tipo `kubernetes.io/tls` com `tls.crt`/`tls.key`.
- O exemplo pronto fica na doc, em *Ingress → TLS*. Copie e ajuste.

---

## Q2 (Médio): gerar certificado, criar a Secret, ativar TLS e redirect 308

### 1. Gerar chave e certificado

```bash
mkdir -p /opt/course/ingress2
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /opt/course/ingress2/shop.key \
  -out /opt/course/ingress2/shop.crt \
  -subj "/CN=shop.cks.local" \
  -addext "subjectAltName=DNS:shop.cks.local"

openssl x509 -in /opt/course/ingress2/shop.crt -noout -subject -dates -ext subjectAltName
```

- `-x509` gera um certificado autoassinado direto, sem CSR.
- `-nodes` grava a chave sem passphrase. O controller não consegue ler uma chave cifrada.
- `-addext` exige OpenSSL 1.1.1 ou mais novo (o Ubuntu do Killercoda tem 3.x).

### 2. Secret

```bash
k -n shop create secret tls shop-tls \
  --cert=/opt/course/ingress2/shop.crt --key=/opt/course/ingress2/shop.key
```

### 3 e 4. Ingress com TLS e redirect

O setup deixou a annotation `nginx.ingress.kubernetes.io/ssl-redirect: "false"`, que **desliga** o redirect padrão. Remova a annotation (ou troque para `"true"`) e adicione o TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop
  namespace: shop
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"     # ou simplesmente remover a annotation
    # alternativa equivalente: nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - shop.cks.local
    secretName: shop-tls
  rules:
  - host: shop.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop
            port:
              number: 80
```

Atalhos rápidos:

```bash
k -n shop annotate ingress shop nginx.ingress.kubernetes.io/ssl-redirect-     # remove a annotation
k -n shop patch ingress shop --type=merge \
  -p '{"spec":{"tls":[{"hosts":["shop.cks.local"],"secretName":"shop-tls"}]}}'
```

### Validação manual

```bash
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' \
  --resolve shop.cks.local:$HTTP:$IP http://shop.cks.local:$HTTP/cart
# 308 https://shop.cks.local/cart

curl -k --resolve shop.cks.local:$HTTPS:$IP https://shop.cks.local:$HTTPS/
# backend=shop
```

### Pegadinhas

- Ler as annotations do Ingress (`k -n shop get ing shop -o yaml`). Um `ssl-redirect: "false"` esquecido derruba o requisito do 308.
- O redirect aponta para `https://host/...` **sem a porta do NodePort**, porque o nginx redireciona para a 443 padrão. Isso é esperado.
- Conferir se chave e certificado combinam:
  `diff <(openssl pkey -in shop.key -pubout) <(openssl x509 -in shop.crt -noout -pubkey)`.

---

## Q3 (Difícil): troubleshooting de Ingress com vários hosts e paths

### Investigação

```bash
k -n portal get ing portal -o yaml
k -n portal get svc,ep
k -n portal describe ing portal          # mostra "service admin-svc not found" e os backends
k get secret -A | grep portal-tls        # a Secret está em default, não em portal
k -n ingress-nginx logs deploy/ingress-nginx-controller | tail -20
```

Problemas plantados:

| Sintoma | Causa |
|---|---|
| Fake Certificate em portal.cks.local | A Secret `portal-tls` foi criada no namespace **default**, e o Ingress está em `portal` |
| Fake Certificate em admin.cks.local | `admin.cks.local` não está em `spec.tls[].hosts`, e o certificado antigo não tem SAN para ele |
| `/api` responde 503 | O backend aponta para a porta **8080** do Service `api`, mas o Service expõe a **80** (8080 é a targetPort) |
| `/api/v1/...` cai no `web` | `pathType: Exact` só casa `/api` exato. É preciso usar `Prefix` |
| admin responde 503 | O backend referencia o Service `admin-svc`, que não existe. O correto é `admin` |

### 1. Novo certificado com SAN para os dois hosts

```bash
mkdir -p /opt/course/ingress3
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /opt/course/ingress3/portal.key \
  -out /opt/course/ingress3/portal.crt \
  -subj "/CN=portal.cks.local" \
  -addext "subjectAltName=DNS:portal.cks.local,DNS:admin.cks.local"

openssl x509 -in /opt/course/ingress3/portal.crt -noout -ext subjectAltName
```

Um wildcard `DNS:*.cks.local` também cobriria os dois hosts, mas listar os nomes explicitamente é mais restritivo e é o que costuma ser pedido.

### 2. Secret no namespace certo

```bash
k -n portal create secret tls portal-tls \
  --cert=/opt/course/ingress3/portal.crt --key=/opt/course/ingress3/portal.key
# opcional, para limpar: a Secret em default é inútil para este Ingress
k -n default delete secret portal-tls
```

### 3. Ingress corrigido

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: portal
  namespace: portal
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - portal.cks.local
    - admin.cks.local
    secretName: portal-tls
  rules:
  - host: portal.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
      - path: /api
        pathType: Prefix          # era Exact
        backend:
          service:
            name: api
            port:
              number: 80          # era 8080 (a targetPort, não a porta do Service)
  - host: admin.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin           # era admin-svc
            port:
              number: 80
```

```bash
k -n portal apply -f portal-ing.yaml   # ou k -n portal edit ing portal
```

Com os dois hosts em `tls` e o certificado válido, o `ssl-redirect` padrão já entrega o 308 para os dois.

### 4. NodePort HTTPS

```bash
k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' > /opt/course/ingress3/https-nodeport
cat /opt/course/ingress3/https-nodeport
```

### Validação manual

```bash
for u in portal.cks.local/ portal.cks.local/api portal.cks.local/api/v1/health admin.cks.local/x; do
  h=${u%%/*}; p=/${u#*/}
  echo -n "$u -> "; curl -sk --resolve $h:$HTTPS:$IP https://$h:$HTTPS$p
done
# portal.cks.local/ -> backend=web
# portal.cks.local/api -> backend=api
# portal.cks.local/api/v1/health -> backend=api
# admin.cks.local/x -> backend=admin

for h in portal.cks.local admin.cks.local; do
  echo | openssl s_client -connect $IP:$HTTPS -servername $h 2>/dev/null \
    | openssl x509 -noout -subject -ext subjectAltName
done
```

### Pegadinhas e conceitos

- **A Secret precisa estar no namespace do Ingress.** Esse é o erro mais comum quando aparece Fake Certificate.
- **`tls.hosts` precisa listar cada host** que deve receber o certificado. O ingress-nginx também confere se o certificado cobre o host (SAN). Se não cobrir, ele serve o certificado fake para aquele host.
- **`port.number` no backend do Ingress é a porta do Service** (`spec.ports[].port`), não a `targetPort` do container.
- **`Exact` x `Prefix`**: `Prefix` em `/api` casa `/api`, `/api/` e `/api/v1/...` (por elemento do path, então `/apix` não casa). `Exact` casa só `/api`.
- Não "corrija" criando um Service `admin-svc`: o enunciado proíbe, e na prova isso conta como alterar o lugar errado.
- Dica de velocidade: `k -n portal create ingress portal --class=nginx --rule="portal.cks.local/*=web:80,tls=portal-tls" --rule="portal.cks.local/api*=api:80,tls=portal-tls" --rule="admin.cks.local/*=admin:80,tls=portal-tls" --dry-run=client -o yaml` gera o YAML completo (o `*` no final vira `pathType: Prefix`). Depois é só `k -n portal delete ing portal` e aplicar, ou comparar com o atual.
