#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

info "Recriando namespace immutable..."
ns_fresh immutable

cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logger
  namespace: immutable
  labels: {app: logger}
spec:
  replicas: 1
  selector:
    matchLabels: {app: logger}
  template:
    metadata:
      labels: {app: logger}
    spec:
      containers:
      - name: logger
        image: busybox:1.36
        command:
        - sh
        - -c
        - mkdir -p /app/logs; while true; do echo "$(date) request processed" >> /app/logs/app.log; sleep 5; done
EOF

kubectl -n immutable rollout status deploy/logger --timeout=120s >/dev/null 2>&1

echo
ok "Ambiente pronto! Leia o enunciado.md"
