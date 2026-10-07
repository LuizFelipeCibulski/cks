#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=seccomp-q1

info "Criando cenário em $NS..."
ns_fresh "$NS"
kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: $NS
  labels:
    app: web
spec:
  securityContext:
    seccompProfile:
      type: Unconfined
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: legacy
  namespace: $NS
  labels:
    app: legacy
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      seccompProfile:
        type: Unconfined
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
EOF
wait_pods "$NS"

echo
ok "Ambiente pronto! Leia o enunciado.md"
