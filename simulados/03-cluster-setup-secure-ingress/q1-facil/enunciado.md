# Secure Ingress — Q1 (Fácil)

**Domínio:** Cluster Setup (15%) · **Tempo sugerido:** ~4 min

## Preparação

```bash
bash setup.sh   # como root no controlplane
```

O setup garante que o **ingress-nginx** (IngressClass `nginx`) está instalado e mostra os NodePorts HTTP/HTTPS do controller e o IP do controlplane.

## Contexto

No namespace `secure-web` existe a aplicação `web` publicada pelo Ingress `web` para o host `web.cks.local`, porém apenas em HTTP. Ao acessar via HTTPS, o controller entrega o certificado padrão *Kubernetes Ingress Controller Fake Certificate*.

O time de segurança já gerou o par de chave/certificado para o host:

- Certificado: `/opt/course/ingress1/tls.crt`
- Chave privada: `/opt/course/ingress1/tls.key`

## Tarefa

1. Crie uma Secret do tipo TLS chamada `web-tls` no namespace `secure-web` usando os arquivos acima.
2. Configure o Ingress `web` (namespace `secure-web`) para terminar TLS para o host `web.cks.local` usando a Secret `web-tls`.
3. Não altere as regras de roteamento existentes do Ingress.

O acesso `https://web.cks.local` (através do NodePort HTTPS do ingress controller) deve responder pela aplicação e apresentar o certificado de `/opt/course/ingress1/tls.crt`.

## Documentação permitida

- https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
- https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
- https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_tls/
- https://kubernetes.github.io/ingress-nginx/user-guide/tls/

---

Quando terminar: `bash verify.sh`
