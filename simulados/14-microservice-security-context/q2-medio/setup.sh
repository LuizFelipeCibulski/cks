#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespaces team-alpha, team-beta, team-gamma..."
ns_fresh team-alpha; ns_fresh team-beta; ns_fresh team-gamma
rm -rf /opt/course/14/q2 && mkdir -p /opt/course/14/q2

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Pod
metadata: {name: web, namespace: team-alpha, labels: {app: web}}
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata: {name: debug-tools, namespace: team-alpha, labels: {app: debug-tools}}
spec:
  containers:
  - name: tools
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      privileged: true
---
apiVersion: v1
kind: Pod
metadata: {name: log-agent, namespace: team-alpha, labels: {app: log-agent}}
spec:
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
---
apiVersion: v1
kind: Pod
metadata: {name: api, namespace: team-beta, labels: {app: api}}
spec:
  containers:
  - name: api
    image: httpd:2.4-alpine
    securityContext:
      privileged: false
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: metrics-collector, namespace: team-beta}
spec:
  replicas: 2
  selector: {matchLabels: {app: metrics-collector}}
  template:
    metadata: {labels: {app: metrics-collector}}
    spec:
      containers:
      - name: collector
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
      - name: node-exporter
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
        securityContext:
          privileged: true
---
apiVersion: v1
kind: Pod
metadata: {name: bootstrap, namespace: team-gamma, labels: {app: bootstrap}}
spec:
  initContainers:
  - name: sysctl-tuner
    image: busybox:1.36
    command: ["sh", "-c", "echo tuning done"]
    securityContext:
      privileged: true
  containers:
  - name: app
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata: {name: worker, namespace: team-gamma, labels: {app: worker}}
spec:
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      allowPrivilegeEscalation: false
YAML

wait_pods team-alpha; wait_pods team-beta; wait_pods team-gamma
echo
echo "Ambiente pronto! Leia o enunciado.md"
