#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root
ns_fresh d6
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: d6}
spec:
  replicas: 2
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: web, namespace: d6}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 8080}]
---
apiVersion: v1
kind: Pod
metadata: {name: legacy-root, namespace: d6, labels: {app: legacy}}
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    securityContext: {privileged: true}
YAML
kubectl -n d6 rollout status deploy/web --timeout=180s >/dev/null 2>&1
wait_pods d6
echo; ok "Ambiente pronto! Leia o enunciado.md"
