#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespaces apps-prod e apps-dev..."
ns_fresh apps-prod
ns_fresh apps-dev
rm -rf /opt/course/13/q2 && mkdir -p /opt/course/13/q2

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: apps-prod
  labels: {app: frontend}
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: web
    image: nginxinc/nginx-unprivileged:1.27-alpine
    ports:
    - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: apps-prod
  labels: {app: backend}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: cache
  namespace: apps-prod
  labels: {app: cache}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
---
apiVersion: v1
kind: Pod
metadata:
  name: metrics
  namespace: apps-prod
  labels: {app: metrics}
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: metrics
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
---
apiVersion: v1
kind: Pod
metadata:
  name: debug
  namespace: apps-prod
  labels: {app: debug}
spec:
  hostNetwork: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: debug
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
---
apiVersion: v1
kind: Pod
metadata:
  name: worker
  namespace: apps-dev
  labels: {app: worker}
spec:
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
YAML

wait_pods apps-prod
wait_pods apps-dev
echo
echo "Ambiente pronto! Leia o enunciado.md"
