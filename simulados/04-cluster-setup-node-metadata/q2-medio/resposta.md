## Resposta

Yaml para network policy
```
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-deny-metadata
  namespace: payments
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
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
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: payments
```