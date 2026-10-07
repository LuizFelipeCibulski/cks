# Secure Ingress — Q2 (Médio)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~7 min

## Preparação

```bash
bash setup.sh   # como root no controlplane
```

O setup garante que o **ingress-nginx** (IngressClass `nginx`) está instalado e mostra os NodePorts HTTP/HTTPS do controller e o IP do controlplane.

## Contexto

A loja virtual roda no namespace `shop` e é exposta pelo Ingress `shop` para o host `shop.cks.local`. Hoje ela só funciona em texto puro (HTTP). A política da empresa exige que todo tráfego seja cifrado e que clientes que cheguem por HTTP sejam enviados para HTTPS.

## Tarefa

1. Gere com `openssl` um certificado **autoassinado** e sua chave privada:
   - chave RSA de **2048 bits**, sem passphrase, em `/opt/course/ingress2/shop.key`
   - certificado em `/opt/course/ingress2/shop.crt`, válido por **365 dias**
   - Subject `CN=shop.cks.local` e **Subject Alternative Name** `DNS:shop.cks.local`
2. Crie a Secret TLS `shop-tls` no namespace `shop` com esse par.
3. Configure o Ingress `shop` para servir `shop.cks.local` via HTTPS usando `shop-tls`.
4. Requisições `http://shop.cks.local/<qualquer-path>` devem receber um redirecionamento permanente (**HTTP 308**) para `https://shop.cks.local/<mesmo-path>`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/
- https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/
- https://docs.openssl.org/3.0/man1/openssl-req/

---

Quando terminar: `bash verify.sh`
