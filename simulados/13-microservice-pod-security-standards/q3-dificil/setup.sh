#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests/kube-apiserver.yaml
# Volta o kube-apiserver ao original (se uma tentativa anterior o alterou)
if [ -f /root/cks-backup/kube-apiserver.yaml ] && ! cmp -s /root/cks-backup/kube-apiserver.yaml "$M"; then
  info "Restaurando kube-apiserver.yaml original de /root/cks-backup..."
  cp /root/cks-backup/kube-apiserver.yaml "$M"
  sleep 20
fi
wait_apiserver || exit 1
backup_manifest kube-apiserver.yaml
rm -rf /etc/kubernetes/psa

info "Recriando namespaces checkout e legacy-batch..."
ns_fresh checkout
ns_fresh legacy-batch
kubectl label ns legacy-batch pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest >/dev/null
rm -rf /opt/course/13/q3 && mkdir -p /opt/course/13/q3

kubectl apply -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-api
  namespace: checkout
  labels: {app: checkout-api}
spec:
  replicas: 2
  selector:
    matchLabels: {app: checkout-api}
  template:
    metadata:
      labels: {app: checkout-api}
    spec:
      initContainers:
      - name: init-config
        image: busybox:1.36
        command: ["sh", "-c", "echo ready > /work/ready"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: work
          mountPath: /work
      containers:
      - name: api
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
        securityContext:
          runAsUser: 0
        volumeMounts:
        - name: work
          mountPath: /work
        - name: logs
          mountPath: /var/log/app
      volumes:
      - name: work
        emptyDir: {}
      - name: logs
        hostPath:
          path: /var/log/checkout
          type: DirectoryOrCreate
YAML

kubectl -n checkout rollout status deploy checkout-api --timeout=180s >/dev/null 2>&1
echo
echo "Ambiente pronto! Leia o enunciado.md"
