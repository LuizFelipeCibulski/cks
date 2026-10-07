#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# --- Esta questão exige Cilium como CNI ---
if ! kubectl -n kube-system get ds cilium >/dev/null 2>&1 || ! kubectl -n kube-system get cm cilium-config >/dev/null 2>&1; then
  echo -e "${RED}ERRO:${NC} o CNI deste cluster não parece ser o Cilium (DaemonSet kube-system/cilium ou ConfigMap cilium-config ausente)."
  echo "Esta questão exige Cilium (use o playground CKS do Killercoda). Abortando."
  exit 1
fi

if ! command -v cilium >/dev/null; then
  info "Instalando cilium CLI..."
  v=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt 2>/dev/null); [ -z "$v" ] && v=v0.20.1
  curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${v}/cilium-linux-amd64.tar.gz" | tar xz -C /usr/local/bin cilium || true
fi

command -v jq >/dev/null || { apt-get update -qq >/dev/null; apt-get install -y jq >/dev/null 2>&1; }

# --- Backup único da configuração original do Cilium ---
mkdir -p /root/cks-backup
[ -f /root/cks-backup/cilium-config.yaml ] || kubectl -n kube-system get cm cilium-config -o yaml > /root/cks-backup/cilium-config.yaml

# --- Estado limpo: WireGuard desabilitado ---
cur=$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')
if [ "$cur" = "true" ]; then
  info "Desabilitando WireGuard (estado inicial da questão) e reiniciando agentes do Cilium..."
  kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}' >/dev/null
  kubectl -n kube-system rollout restart ds/cilium >/dev/null
  kubectl -n kube-system rollout status ds/cilium --timeout=300s >/dev/null 2>&1 || true
fi

rm -rf /opt/course/17
mkdir -p /opt/course/17

info "Recriando namespace secure-payments..."
ns_fresh secure-payments

CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
WK=$(worker_node)
[ -z "$WK" ] && WK=$CP   # sem node01: tudo no controlplane

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: secure-payments
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${WK}
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: api
        image: nginxinc/nginx-unprivileged:1.27-alpine
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: payment-api
  namespace: secure-payments
spec:
  selector:
    app: payment-api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Pod
metadata:
  name: payment-client
  namespace: secure-payments
  labels:
    app: payment-client
spec:
  nodeSelector:
    kubernetes.io/hostname: ${CP}
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: secure-payments
  labels:
    app: attacker
spec:
  nodeSelector:
    kubernetes.io/hostname: ${CP}
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
  containers:
  - name: c
    image: busybox:1.36
    command: ["sleep", "1d"]
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: payment-api-monitoring
  namespace: secure-payments
  labels:
    owner: netops
spec:
  description: "scrape de metricas (legado)"
  endpointSelector:
    matchLabels:
      app: payment-api
  ingress:
  - fromEntities:
    - cluster
EOF

info "Aguardando Pods..."
wait_pods secure-payments

echo
echo "Ambiente pronto! Leia o enunciado.md"
