## Resposta

Yamls:
```
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: api-l7
  namespace: shop
spec:
  description: "Allow HTTP GET /public from app=client to app=api"
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/public.*"
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: "client-deny-world"
  namespace: shop
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toEndpoints:
    - matchLabels:
       "k8s:io.kubernetes.pod.namespace": kube-system
       "k8s:k8s-app": kube-dns
    toPorts:
      - ports:
         - port: "53"
           protocol: ANY
  egressDeny:
  - toEntities: 
    - world
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: "clientapi"
  namespace: shop
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toEndpoints:
    - matchLabels:
       "k8s:io.kubernetes.pod.namespace": shop
       "k8s:app": api
    toPorts:
      - ports:
         - port: "80"
           protocol: TCP
```