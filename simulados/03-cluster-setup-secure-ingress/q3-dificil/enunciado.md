# Secure Ingress — Q3 (Difícil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~12 min

## Preparação

```bash
bash setup.sh   # como root no controlplane
```

## Contexto

No namespace `portal` rodam três aplicações (Deployments e Services `web`, `api` e `admin`). Cada uma responde com o texto `backend=<nome>` em qualquer path. Elas são publicadas pelo Ingress `portal` (IngressClass `nginx`).

O time de plataforma relata vários problemas:

- O navegador recebe o certificado *Kubernetes Ingress Controller Fake Certificate* em `https://portal.cks.local`.
- Chamadas para `https://portal.cks.local/api/v1/...` não chegam na API; chamadas para `/api` retornam erro.
- `https://admin.cks.local` retorna 503 e também não tem certificado válido.

## Tarefa

1. Gere um novo par chave/certificado autoassinado com `openssl`:
   - chave em `/opt/course/ingress3/portal.key` e certificado em `/opt/course/ingress3/portal.crt`
   - Subject `CN=portal.cks.local`
   - o certificado deve ser válido (SAN) para **`portal.cks.local` e `admin.cks.local`**
2. Disponibilize esse par numa Secret TLS chamada `portal-tls` que possa ser usada pelo Ingress `portal`.
3. Corrija o Ingress `portal` para que o roteamento via HTTPS fique exatamente assim:

   | URL | Backend |
   |-----|---------|
   | `https://portal.cks.local/` (e demais paths) | Service `web` |
   | `https://portal.cks.local/api` e **qualquer subpath** `/api/...` | Service `api` |
   | `https://admin.cks.local/` (qualquer path) | Service `admin` |

4. Os dois hosts devem apresentar o certificado de `/opt/course/ingress3/portal.crt`, e acessos HTTP a qualquer um deles devem ser redirecionados para HTTPS.
5. **Não** crie novos Services nem altere Deployments/Services existentes — o problema está na configuração de entrada.
6. Grave em `/opt/course/ingress3/https-nodeport` apenas o número do NodePort HTTPS do ingress controller.

Valide você mesmo com `curl --resolve` contra o IP do controlplane antes de rodar o verify.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/ingress/
- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/
- https://kubernetes.github.io/ingress-nginx/troubleshooting/
- https://docs.openssl.org/3.0/man1/openssl-req/

---

Quando terminar: `bash verify.sh`
