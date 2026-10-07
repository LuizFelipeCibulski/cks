## Resposta

Yaml de ingress: 

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway-ingress
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: gateway
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
         kubernetes.io/metadata.name: orders 
      podSelector:
        matchLabels:
          app: api
    ports:
    - protocol: TCP
      port: 80
```

Yaml do egress: 

```
---
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
       - podSelector:
           matchLabels:
             app: gateway
         namespaceSelector:
           matchLabels:
             kubernetes.io/metadata.name: payments
      ports:
        - protocol: TCP
          port: 80
    - to:
       - podSelector:
           matchLabels:
             k8s-app: kube-dns 
         namespaceSelector:
           matchLabels:
             kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53
```