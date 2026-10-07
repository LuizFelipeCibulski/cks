#!/usr/bin/env bash
# Node Metadata Protection — Q1 (Fácil): setup
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# ---------------------------------------------------------------------------
# "Nuvem" simulada no controlplane:
#   - 169.254.169.254 -> metadata server (com credenciais IAM falsas)
#   - 198.51.100.10   -> uma API "externa" qualquer
# Os IPs ficam dentro de um network namespace (cks-meta) ligado ao host por um
# veth. Assim, para o CNI (Cilium) esses IPs são destinos EXTERNOS (world),
# exatamente como o metadata server de um provedor de nuvem real.
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

# Os pods ficam no controlplane, onde a "nuvem" simulada existe
CP_HOST=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.labels.kubernetes\.io/hostname}')
[ -z "$CP_HOST" ] && CP_HOST=$(hostname)

info "Recriando namespaces cloud-app e cks-probe..."
ns_fresh cloud-app
ns_fresh cks-probe

pod() { # pod <ns> <name> <image> <labels-yaml-inline> <cmd>
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: $2
  namespace: $1
  labels: $4
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
    image: $3
$5
EOF
}

pod cloud-app web    nginx:1.27-alpine "{app: web}" ""
pod cloud-app worker busybox:1.36      "{app: worker}" '    command: ["sh","-c","sleep 1d"]'
# pod de controle (NÃO faz parte da tarefa): usado pelo verify para checar o ambiente
pod cks-probe probe  busybox:1.36      "{app: probe}" '    command: ["sh","-c","sleep 1d"]'

wait_pods cloud-app
wait_pods cks-probe

if kubectl -n cks-probe exec probe -- wget -T3 -qO- http://169.254.169.254/ 2>/dev/null | grep -q fake-cloud-metadata; then
  ok "metadata simulado acessível a partir de pods"
else
  echo "AVISO: o pod de controle não alcançou 169.254.169.254; o verify pode não ser confiável neste cluster."
fi

echo
echo "Ambiente pronto! Leia o enunciado.md"
