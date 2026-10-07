#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# --- Esta questão exige Cilium como CNI ---
if ! kubectl -n kube-system get ds cilium >/dev/null 2>&1; then
  echo -e "${RED}ERRO:${NC} o CNI deste cluster não parece ser o Cilium (DaemonSet kube-system/cilium não encontrado)."
  echo "Esta questão exige Cilium (use o playground CKS do Killercoda). Abortando."
  exit 1
fi

if ! command -v cilium >/dev/null; then
  info "Instalando cilium CLI..."
  v=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt 2>/dev/null); [ -z "$v" ] && v=v0.20.1
  curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${v}/cilium-linux-amd64.tar.gz" | tar xz -C /usr/local/bin cilium || true
fi

info "Recriando namespace shop..."
ns_fresh shop

kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: shop
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    command: ["sh", "-c"]
    args:
    - |
      mkdir -p /usr/share/nginx/html/public /usr/share/nginx/html/private
      echo "catalogo publico" > /usr/share/nginx/html/public/index.html
      echo "DADOS ADMINISTRATIVOS" > /usr/share/nginx/html/private/index.html
      exec nginx -g 'daemon off;'
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: shop
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: shop
  labels:
    app: client
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: intruder
  namespace: shop
  labels:
    app: intruder
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
EOF

info "Aguardando Pods..."
wait_pods shop

echo
echo "Ambiente pronto! Leia o enunciado.md"
