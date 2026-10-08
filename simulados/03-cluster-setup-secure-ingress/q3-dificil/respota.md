## Resposta
Gerar .key:
```
openssl genrsa -out /opt/course/ingress3/portal.key 2048
```

Gerar o crt com parametros corretos:
```
openssl req -x509 -new -noenc -key /opt/course/ingress3/portal.key -subj "/CN=portal.cks.local" -addext "subjectAltName=DNS:portal.cks.local,DNS:admin.cks.local" -days 365 -out /opt/course/ingress3/portal.crt
```
```
kubectl create secret tls portal-tls --cert=/opt/course/ingress3/portal.crt --key=/opt/course/ingress3/portal.key
```

Yaml do ingress: 
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  creationTimestamp: "2026-10-08T13:53:23Z"
  generation: 6
  name: portal
  namespace: portal
  resourceVersion: "54299"
  uid: 6eca9ddb-8346-4d65-8358-a370f343fe46
spec:
  ingressClassName: nginx
  rules:
  - host: portal.cks.local
    http:
      paths:
      - backend:
          service:
            name: web
            port:
              number: 80
        path: /
        pathType: Prefix
      - backend:
          service:
            name: api
            port:
              number: 80
        path: /api
        pathType: Prefix
  - host: admin.cks.local
    http:
      paths:
      - backend:
          service:
            name: admin
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - admin.cks.local
    secretName: portal-tls
  - hosts:
    - portal.cks.local
    secretName: portal-tls
status:
  loadBalancer:
    ingress:
    - ip: 172.30.2.2
```