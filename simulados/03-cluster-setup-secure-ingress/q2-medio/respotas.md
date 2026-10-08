## Resposta

Criação do .key
```
openssl genrsa -out /opt/course/ingress2/shop.key 2048
```

Criação do .crt
```
openssl req -x509 -new -noenc -key /opt/course/ingress2/shop.key -subj "/CN=shop.cks.local" -addext "subjectAltName=DNS:shop.cks.local" -days 365 -out /opt/course/ingress2/shop.crt
```

Criação do secret
```
kubectl create secret tls my-tls-secret --cert=/opt/course/ingress2/shop.crt --key=/opt/course/ingress2/shop.key
```


Mudança no ingress:
```
annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"

spec:
  tls:
  - hosts:
      - https-example.foo.com
    secretName: testsecret-tls
```