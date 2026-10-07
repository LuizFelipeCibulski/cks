#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

info "Limpando tentativas anteriores..."
kubectl delete validatingadmissionpolicybinding trusted-registries-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy trusted-registries --ignore-not-found >/dev/null 2>&1
rm -rf /opt/course/21/q2
mkdir -p /opt/course/21/q2

ns_fresh team-blue
ns_fresh team-green

info "Criando Pods em team-blue e team-green..."
cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: web-frontend
  namespace: team-blue
  labels: {app: web-frontend}
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: cache
  namespace: team-blue
  labels: {app: cache}
spec:
  initContainers:
  - name: warmup
    image: busybox:1.36
    command: ["sh", "-c", "echo warming cache; sleep 2"]
  containers:
  - name: cache
    image: registry.k8s.io/pause:3.10
---
apiVersion: v1
kind: Pod
metadata:
  name: metrics
  namespace: team-blue
  labels: {app: metrics}
spec:
  containers:
  - name: metrics
    image: registry.k8s.io/pause:3.10
---
apiVersion: v1
kind: Pod
metadata:
  name: legacy
  namespace: team-blue
  labels: {app: legacy}
spec:
  containers:
  - name: httpd
    image: docker.io/library/httpd:2.4-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: metrics-proxy
  namespace: team-blue
  labels: {app: metrics-proxy}
spec:
  containers:
  - name: main
    image: registry.k8s.io/pause:3.10
  - name: proxy
    image: registry.k8s.io.mirror-cdn.com/pause:3.10
---
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: team-blue
  labels: {app: probe}
spec:
  containers:
  - name: probe
    image: registry.k8s.io/e2e-test-images/agnhost:2.53
    args: ["pause"]
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: team-green
  labels: {app: web}
spec:
  containers:
  - name: web
    image: nginx:1.27-alpine
EOF

wait_pods team-green
sleep 5

echo
ok "Ambiente pronto! Leia o enunciado.md"
