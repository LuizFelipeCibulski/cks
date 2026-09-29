Cluster Setup - Network Policies:

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-out
  namespace: app
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

Este network police vai ser aplicado para o namespace app.
podSelector: {} - Seleciona todos os pods de uma namespace, no caso app.
policyTypes: Controla o tráfego, tanto ingress quanto egress.

igress: - Aqui definimos a permissão de entrada dos pods.
egress: - Aqui definimos a permissão para de saída dos pods, para onde ele vai poder sair

No exemplo de cima: 

                  ┌── TCP/53 ──► qualquer destino
Pod app ─ EGRESS ─┤
                  └── UDP/53 ──► qualquer destino


---
Allow communication between two Namespaces.

Restringir saída apenas para o ns space2

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space1
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: space2
    ports:
      - protocol: TCP
        port: 80
  - to:
    - namespaceSelector: # Consultar DNS
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchlabels:
          k8s-app=kube-dns
    ports:
      - protocol: TCP # Consultar DNS
        port: 53
      - protocol: UDP # Consultar DNS
        port: 53

Visualmente:

                  ┌───────────────┐
                  │    space1     │
                  │               │
                  │    Pod        │
                  └───────┬───────┘
                          │
              ┌───────────┴───────────┐
              │                       │
           TCP/80                  TCP/53
              │                    UDP/53
              ▼                       ▼
        ┌───────────┐           ┌─────────────┐
        │  space2   │           │ kube-system │
        │           │           │             │
        │ :80  ✓    │           │ CoreDNS :53 │
        └───────────┘           └─────────────┘

Restringir entrada apenas pelo namespace1

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np
  namespace: space2
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: space1
  egress:
  - ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

---
