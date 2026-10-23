## Resposta

```
k edit configmap -n kube-system cilium-config


enable-wireguard: "true"

k rollout restart ds -n kube-system cilium

kubectl -n kube-system exec -ti ds/cilium -- cilium-dbg status | grep Encryption > /opt/course/17/encrypt-status.txt


```

```
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "payment-api-ingress"
  namespace: secure-payments
spec:
  description: "L3-L4 policy to restrict app: payment-api access to app: payment-client"
  endpointSelector:
    matchLabels:
      app: payment-api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: payment-client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```



```
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "payment-api-mutual-auth"
  namespace: secure-payments
spec:
  description: "L3-L4 policy to restrict app: payment-api access to app: payment-client"
  endpointSelector:
    matchLabels:
      app: payment-api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: payment-client
    authentication:
      mode: "required"
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
```

