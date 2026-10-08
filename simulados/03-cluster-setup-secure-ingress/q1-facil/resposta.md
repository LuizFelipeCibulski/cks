## Resposta

Criar tls:
```
kubectl create secret tls web-tls -n secure-web --cert=/opt/course/ingress1/tls.crt --key=/opt/course/ingress1/tls.key
```


Yamls com tls ingress:
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: secure-web
spec:
  ingressClassName: nginx
  rules:
  - host: web.cks.local
    http:
      paths:
      - backend:
          service:
            name: web
            port:
              number: 80
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - web.cks.local
    secretName: web-tls
```