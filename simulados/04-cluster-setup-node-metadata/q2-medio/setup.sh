#!/usr/bin/env bash
# Node Metadata Protection — Q2 (Médio): setup
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# ---------------------------------------------------------------------------
# "Nuvem" simulada no controlplane (veja comentários na Q1):
#   169.254.169.254 -> metadata server | 198.51.100.10 -> API externa
# ---------------------------------------------------------------------------
setup_fake_cloud() {
  info "Simulando metadata server (169.254.169.254) e API externa (198.51.100.10)..."
  command -v python3 >/dev/null || { apt-get update -qq >/dev/null; apt-get install -y python3 >/dev/null 2>&1; }
  systemctl stop cks-metadata-meta cks-metadata-ext >/dev/null 2>&1
  systemctl reset-failed cks-metadata-meta cks-metadata-ext >/dev/null 2>&1
  ip netns del cks-meta 2>/dev/null
  ip link del meta-host 2>/dev/null

  mkdir -p /opt/cks-metadata/meta/latest/meta-data/iam/security-credentials /opt/cks-metadata/ext
  echo "fake-cloud-metadata: ami-id instance-id iam/security-credentials/" > /opt/cks-metadata/meta/index.html
  cat > /opt/cks-metadata/meta/latest/meta-data/iam/security-credentials/node-role <<'EOF'
{"Code":"Success","AccessKeyId":"ASIAFAKEFAKEFAKE","SecretAccessKey":"iam-credentials-super-secretas","Token":"FAKE"}
EOF
  echo "external-api: ok" > /opt/cks-metadata/ext/index.html

  ip netns add cks-meta
  ip link add meta-host type veth peer name meta-ns
  ip link set meta-ns netns cks-meta
  ip addr add 169.254.169.253/30 dev meta-host
  ip link set meta-host up
  ip -n cks-meta link set lo up
  ip -n cks-meta addr add 169.254.169.254/30 dev meta-ns
  ip -n cks-meta addr add 198.51.100.10/32 dev meta-ns
  ip -n cks-meta link set meta-ns up
  ip -n cks-meta route add default via 169.254.169.253
  ip route replace 198.51.100.10/32 via 169.254.169.254 dev meta-host
  sysctl -qw net.ipv4.ip_forward=1 net.ipv4.conf.meta-host.rp_filter=0 >/dev/null 2>&1
  if command -v iptables >/dev/null; then
    iptables -C FORWARD -i meta-host -j ACCEPT 2>/dev/null || iptables -I FORWARD -i meta-host -j ACCEPT
    iptables -C FORWARD -o meta-host -j ACCEPT 2>/dev/null || iptables -I FORWARD -o meta-host -j ACCEPT
  fi

  systemd-run --quiet --unit=cks-metadata-meta -p Restart=always \
    ip netns exec cks-meta python3 -m http.server 80 --bind 169.254.169.254 --directory /opt/cks-metadata/meta
  systemd-run --quiet --unit=cks-metadata-ext -p Restart=always \
    ip netns exec cks-meta python3 -m http.server 80 --bind 198.51.100.10 --directory /opt/cks-metadata/ext

  for _ in $(seq 1 20); do
    curl -s -m 2 http://169.254.169.254/ | grep -q fake-cloud-metadata \
      && curl -s -m 2 http://198.51.100.10/ | grep -q external-api && { ok "nuvem simulada no ar"; return 0; }
    sleep 1
  done
  echo "AVISO: metadata simulado não respondeu no host (veja: systemctl status cks-metadata-meta)"
}

setup_fake_cloud

CP_HOST=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.labels.kubernetes\.io/hostname}')
[ -z "$CP_HOST" ] && CP_HOST=$(hostname)

info "Recriando namespaces payments e cks-probe..."
ns_fresh payments
ns_fresh cks-probe

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-frontend
  namespace: payments
  labels: {app: shop, tier: frontend}
spec:
  replicas: 2
  selector:
    matchLabels: {app: shop, tier: frontend}
  template:
    metadata:
      labels: {app: shop, tier: frontend}
    spec:
      terminationGracePeriodSeconds: 1
      nodeSelector:
        kubernetes.io/hostname: ${CP_HOST}
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: frontend
        image: busybox:1.36
        command: ["sh","-c","sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-backend
  namespace: payments
  labels: {app: shop, tier: backend}
spec:
  replicas: 1
  selector:
    matchLabels: {app: shop, tier: backend}
  template:
    metadata:
      labels: {app: shop, tier: backend}
    spec:
      terminationGracePeriodSeconds: 1
      nodeSelector:
        kubernetes.io/hostname: ${CP_HOST}
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: backend
        image: busybox:1.36
        command: ["sh","-c","sleep 1d"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: payments
  labels: {app: shop, tier: api}
spec:
  replicas: 1
  selector:
    matchLabels: {app: shop, tier: api}
  template:
    metadata:
      labels: {app: shop, tier: api}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: api
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: payments
spec:
  selector: {app: shop, tier: api}
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: probe
  namespace: cks-probe
  labels: {app: probe}
spec:
  terminationGracePeriodSeconds: 1
  nodeSelector:
    kubernetes.io/hostname: ${CP_HOST}
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: c
    image: busybox:1.36
    command: ["sh","-c","sleep 1d"]
EOF

for d in shop-frontend shop-backend api; do
  kubectl -n payments rollout status deploy/$d --timeout=180s >/dev/null 2>&1 || true
done
wait_pods payments
wait_pods cks-probe

if kubectl -n cks-probe exec probe -- wget -T3 -qO- http://169.254.169.254/ 2>/dev/null | grep -q fake-cloud-metadata; then
  ok "metadata simulado acessível a partir de pods"
else
  echo "AVISO: o pod de controle não alcançou 169.254.169.254; o verify pode não ser confiável neste cluster."
fi

echo
echo "Ambiente pronto! Leia o enunciado.md"
