#!/usr/bin/env bash
# Network Policies — Q3 (Difícil): microsegmentação frontend/backend/database com DNS e ipBlock
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# deploy <ns> <nome> <label app> <porta>  — busybox httpd respondendo "<ns>/<nome>"
deploy() {
  kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $2
  namespace: $1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $3
  template:
    metadata:
      labels:
        app: $3
    spec:
      containers:
      - name: $2
        image: busybox:1.36
        command: ["sh", "-c", "mkdir -p /www && echo $1/$2 > /www/index.html && httpd -f -p $4 -h /www"]
        ports:
        - containerPort: $4
EOF
}

info "Recriando namespaces frontend, backend, database e cks-probe..."
for ns in frontend backend database cks-probe; do ns_fresh "$ns"; done

info "Criando Deployments e Services..."
deploy frontend web   web   80
deploy frontend debug debug 80
deploy backend  api   api   8080
deploy backend  batch batch 8080
deploy database db    db    5432
kubectl -n cks-probe run probe --image=busybox:1.36 --labels=app=probe --command -- sleep 1d >/dev/null
kubectl -n frontend expose deploy web --port=80 >/dev/null
kubectl -n backend  expose deploy api --port=8080 >/dev/null
kubectl -n database expose deploy db  --port=5432 >/dev/null

info "Aplicando as políticas deixadas pelo administrador anterior..."
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: frontend
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: frontend
      podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-legacy
  namespace: database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - {}
EOF

for ns in frontend backend database cks-probe; do wait_pods "$ns"; done

echo
echo "Ambiente pronto! Leia o enunciado.md"
