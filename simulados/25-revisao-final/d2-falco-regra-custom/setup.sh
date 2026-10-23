#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane

falco_reset
rm -rf /opt/course/25/d2; mkdir -p /opt/course/25/d2
ns_fresh store; ns_fresh legacy

info "Criando Deployments..."
cat <<'YAML' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalog, namespace: store}
spec:
  replicas: 2
  selector: {matchLabels: {app: catalog}}
  template:
    metadata: {labels: {app: catalog}}
    spec:
      containers: [{name: nginx, image: "nginx:1.27-alpine"}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: reports, namespace: store}
spec:
  replicas: 1
  selector: {matchLabels: {app: reports}}
  template:
    metadata: {labels: {app: reports}}
    spec:
      containers:
      - name: reports
        image: alpine:3.20
        command: ["sh", "-c", "while true; do apk info > /dev/null 2>&1; sleep 8; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: updater, namespace: store}
spec:
  replicas: 1
  selector: {matchLabels: {app: updater}}
  template:
    metadata: {labels: {app: updater}}
    spec:
      containers:
      - name: updater
        image: alpine:3.20
        command: ["sh", "-c", "while true; do ls -l /sbin/apk /etc/apk/world > /dev/null; sleep 8; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: importer, namespace: legacy}
spec:
  replicas: 1
  selector: {matchLabels: {app: importer}}
  template:
    metadata: {labels: {app: importer}}
    spec:
      containers:
      - name: importer
        image: debian:bookworm-slim
        command: ["sh", "-c", "while true; do apt-get --version > /dev/null; sleep 8; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: scheduler, namespace: legacy}
spec:
  replicas: 1
  selector: {matchLabels: {app: scheduler}}
  template:
    metadata: {labels: {app: scheduler}}
    spec:
      containers:
      - name: scheduler
        image: debian:bookworm-slim
        command: ["sh", "-c", "while true; do date > /tmp/last-run; sleep 8; done"]
YAML
for ns in store legacy; do
  for d in $(kubectl -n "$ns" get deploy -o name); do kubectl -n "$ns" rollout status "$d" --timeout=180s >/dev/null 2>&1; done
done
echo; ok "Ambiente pronto! Leia o enunciado.md"
