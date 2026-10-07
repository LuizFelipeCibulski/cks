#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespaces fin-a, fin-b, fin-c..."
ns_fresh fin-a; ns_fresh fin-b; ns_fresh fin-c
rm -rf /opt/course/14/q3 && mkdir -p /opt/course/14/q3

kubectl apply -f - >/dev/null <<'YAML'
# ----------------------------- fin-a
apiVersion: apps/v1
kind: Deployment
metadata: {name: ledger, namespace: fin-a}
spec:
  replicas: 1
  selector: {matchLabels: {app: ledger}}
  template:
    metadata: {labels: {app: ledger}}
    spec:
      containers:
      - name: ledger
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        securityContext:
          privileged: true
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: audit-shipper, namespace: fin-a}
spec:
  replicas: 1
  selector: {matchLabels: {app: audit-shipper}}
  template:
    metadata: {labels: {app: audit-shipper}}
    spec:
      hostPID: true
      securityContext:
        runAsUser: 1000
      containers:
      - name: shipper
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: web, namespace: fin-a}
spec:
  replicas: 1
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
      - name: web
        image: nginxinc/nginx-unprivileged:1.27-alpine
        securityContext:
          allowPrivilegeEscalation: false
---
# ----------------------------- fin-b
apiVersion: apps/v1
kind: Deployment
metadata: {name: cache, namespace: fin-b}
spec:
  replicas: 1
  selector: {matchLabels: {app: cache}}
  template:
    metadata: {labels: {app: cache}}
    spec:
      hostNetwork: true
      securityContext:
        runAsUser: 1000
      containers:
      - name: cache
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: batch, namespace: fin-b}
spec:
  replicas: 1
  selector: {matchLabels: {app: batch}}
  template:
    metadata: {labels: {app: batch}}
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
      containers:
      - name: batch
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        securityContext:
          runAsUser: 0
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: reporter, namespace: fin-b}
spec:
  replicas: 1
  selector: {matchLabels: {app: reporter}}
  template:
    metadata: {labels: {app: reporter}}
    spec:
      hostNetwork: false
      securityContext:
        runAsUser: 2000
        runAsNonRoot: true
      containers:
      - name: reporter
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
# ----------------------------- fin-c
apiVersion: v1
kind: Pod
metadata: {name: metrics, namespace: fin-c, labels: {app: metrics}}
spec:
  containers:
  - name: metrics
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: sidecar-app, namespace: fin-c}
spec:
  replicas: 1
  selector: {matchLabels: {app: sidecar-app}}
  template:
    metadata: {labels: {app: sidecar-app}}
    spec:
      securityContext:
        runAsUser: 1000
      initContainers:
      - name: setup
        image: busybox:1.36
        command: ["sh", "-c", "echo setup ok"]
        securityContext:
          privileged: true
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
      - name: proxy
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: fin-c}
spec:
  replicas: 1
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      securityContext:
        runAsUser: 1001
        runAsNonRoot: true
      containers:
      - name: api
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        securityContext:
          allowPrivilegeEscalation: false
YAML

for ns in fin-a fin-b fin-c; do wait_pods $ns; done
echo
echo "Ambiente pronto! Leia o enunciado.md"
