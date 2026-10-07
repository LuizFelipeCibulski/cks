#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=upgrade-q1
OUT=/opt/course/09/q1
W=$(worker_node)

rm -rf "$OUT"; mkdir -p "$OUT"

if [ -n "$W" ]; then
  info "Garantindo que $W está schedulable (estado limpo)..."
  kubectl uncordon "$W" >/dev/null 2>&1
else
  info "ATENÇÃO: cluster sem node worker — o item 4 (manutenção do node01) será ignorado pelo verify."
fi

info "Atualizando índice do apt..."
apt-get update -qq >/dev/null 2>&1 || info "apt-get update falhou (sem internet?) — o item 3 pode não ser verificável."

info "Criando workloads em $NS..."
ns_fresh "$NS"
kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: $NS
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: web
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        volumeMounts:
        - name: cache
          mountPath: /var/cache/nginx
      volumes:
      - name: cache
        emptyDir: {}
EOF

if [ -n "$W" ]; then
  kubectl apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: debug
  namespace: $NS
spec:
  nodeName: $W
  containers:
  - name: debug
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
EOF
fi

wait_pods "$NS"
echo
ok "Ambiente pronto! Leia o enunciado.md"
