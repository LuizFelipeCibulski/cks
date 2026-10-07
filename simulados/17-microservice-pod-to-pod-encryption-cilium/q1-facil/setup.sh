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
if ! kubectl get crd ciliumnetworkpolicies.cilium.io >/dev/null 2>&1; then
  echo -e "${RED}ERRO:${NC} CRD ciliumnetworkpolicies.cilium.io não encontrado. Abortando."; exit 1
fi

# --- cilium CLI (útil para inspeção) ---
if ! command -v cilium >/dev/null; then
  info "Instalando cilium CLI..."
  v=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt 2>/dev/null); [ -z "$v" ] && v=v0.20.1
  curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${v}/cilium-linux-amd64.tar.gz" | tar xz -C /usr/local/bin cilium || true
fi

info "Recriando namespaces team-blue e team-green..."
ns_fresh team-blue
ns_fresh team-green

kubectl apply -f - >/dev/null <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: team-blue
  labels:
    app: backend
spec:
  containers:
  - name: nginx
    image: nginx:1.27-alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: team-blue
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: team-blue
  labels:
    app: frontend
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: other
  namespace: team-blue
  labels:
    app: other
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: team-green
  labels:
    app: frontend
spec:
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
EOF

info "Aguardando Pods..."
wait_pods team-blue
wait_pods team-green

echo
echo "Ambiente pronto! Leia o enunciado.md"
