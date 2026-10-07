#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

NS=supply-chain
STATE=/var/lib/cks-sim/21-q1
mkdir -p "$STATE"
rm -f "$STATE"/*

info "Recriando namespace $NS..."
ns_fresh "$NS"

cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-api
  namespace: supply-chain
  labels:
    app: payment-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-api
  template:
    metadata:
      labels:
        app: payment-api
    spec:
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
      - name: log-agent
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo heartbeat; sleep 30; done"]
EOF

info "Aguardando os Pods ficarem prontos (pull das imagens)..."
kubectl -n "$NS" rollout status deploy/payment-api --timeout=180s >/dev/null 2>&1
wait_pods "$NS" app=payment-api

# Guarda (para o verify) os digests realmente em execução
POD=$(kubectl -n "$NS" get pod -l app=payment-api -o jsonpath='{.items[0].metadata.name}')
for c in api log-agent; do
  id=$(kubectl -n "$NS" get pod "$POD" -o jsonpath="{.status.containerStatuses[?(@.name=='$c')].imageID}")
  echo "${id##*@}" > "$STATE/$c.digest"
done

if ! grep -q '^sha256:' "$STATE/api.digest" "$STATE/log-agent.digest" 2>/dev/null; then
  echo "Não foi possível obter os digests dos containers (Pods não ficaram prontos?). Rode o setup novamente."
  exit 1
fi

echo
ok "Ambiente pronto! Leia o enunciado.md"
