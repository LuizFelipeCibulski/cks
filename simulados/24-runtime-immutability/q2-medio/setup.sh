#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

info "Recriando namespace frontend..."
ns_fresh frontend

cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: frontend
  labels: {app: web}
spec:
  replicas: 2
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      - name: content
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          while true; do
            echo "<h1>generated at $(date)</h1>" > /tmp/index.html.new
            cp /tmp/index.html.new /html/index.html
            sleep 10
          done
        securityContext:
          readOnlyRootFilesystem: true
        volumeMounts:
        - name: html
          mountPath: /html
      volumes:
      - name: html
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: frontend
spec:
  selector: {app: web}
  ports:
  - port: 80
    targetPort: 80
EOF

sleep 10

echo
ok "Ambiente pronto! Leia o enunciado.md"
