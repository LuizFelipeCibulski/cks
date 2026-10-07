#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

command -v jq >/dev/null || { apt-get update -qq >/dev/null; apt-get install -y jq >/dev/null 2>&1; }
install_kubesec
# --- KubeLinter (release oficial, versão fixa) ---
if ! command -v kube-linter >/dev/null; then
  info "Instalando kube-linter v0.8.3..."
  curl -fsSL https://github.com/stackrox/kube-linter/releases/download/v0.8.3/kube-linter-linux.tar.gz \
    | tar xz -C /usr/local/bin kube-linter
  chmod +x /usr/local/bin/kube-linter
fi
command -v kubesec >/dev/null && command -v kube-linter >/dev/null || { echo "Falha ao instalar kubesec/kube-linter"; exit 1; }

info "Recriando namespace static-app..."
ns_fresh static-app

rm -rf /opt/course/19/q3
mkdir -p /opt/course/19/q3
cat > /opt/course/19/q3/deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: static-app
  labels:
    app: catalog
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
        env:
        - name: API_SECRET
          value: "s3cr3t-4p1-k3y-2024"
        securityContext:
          privileged: true
          allowPrivilegeEscalation: true
---
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: static-app
spec:
  selector:
    app: catalog
  ports:
  - name: http
    port: 80
    targetPort: 80
EOF

kubectl apply -f /opt/course/19/q3/deploy.yaml >/dev/null
info "Aguardando Pods..."
wait_pods static-app

echo
echo "Ambiente pronto! Leia o enunciado.md"
