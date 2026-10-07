#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
B=/root/cks-backup
PKI=/etc/kubernetes/pki

wait_flag() {
  for _ in $(seq 1 90); do
    ps -ww -eo args | grep -E "^$1( |$)" | grep -q -- "$2" && return 0
    sleep 2
  done
  echo "Timeout aguardando $1 com '$2'"; return 1
}

info "Limpando tentativas anteriores..."
rm -rf /opt/course/02/q2
mkdir -p /opt/course/02/q2

install_kube_bench
command -v kube-bench >/dev/null || { echo "Falha ao instalar kube-bench"; exit 1; }

# Restaura outros manifests que este componente pode ter alterado
for f in kube-controller-manager.yaml kube-scheduler.yaml etcd.yaml; do
  [ -f "$B/$f" ] && ! cmp -s "$B/$f" "$M/$f" && cp "$B/$f" "$M/$f"
done

# Estado limpo de arquivos (padrão kubeadm)
chown -R root:root "$PKI"
find "$PKI" -name '*.key' -exec chmod 600 {} +
ETCD_DIR=$(grep -E -- '- --data-dir=' "$M/etcd.yaml" | head -1 | sed 's/.*--data-dir=//; s/[" ]//g')
ETCD_DIR=${ETCD_DIR:-/var/lib/etcd}
chmod 700 "$ETCD_DIR"

info "Preparando kube-apiserver..."
backup_manifest kube-apiserver.yaml
tmp=$(mktemp)
cp -a "$B/kube-apiserver.yaml" "$tmp"
sed -i '/^[[:space:]]*- --profiling=/d' "$tmp"
sed -i 's/^\([[:space:]]*\)- kube-apiserver$/&\n\1- --profiling=true/' "$tmp"
sed -i 's/--authorization-mode=.*/--authorization-mode=AlwaysAllow/' "$tmp"
cp "$tmp" "$M/kube-apiserver.yaml"
rm -f "$tmp"

info "Preparando arquivos do control plane..."
for f in apiserver.key sa.key etcd/peer.key front-proxy-ca.key; do
  [ -f "$PKI/$f" ] && chmod 644 "$PKI/$f"
done
for f in apiserver.crt apiserver-kubelet-client.key etcd; do
  [ -e "$PKI/$f" ] && chown 1000:1000 "$PKI/$f"
done
chmod 755 "$ETCD_DIR"

sleep 5
wait_flag kube-apiserver '--authorization-mode=AlwaysAllow'
wait_apiserver
kubectl -n kube-system wait --for=condition=Ready pod -l component=kube-apiserver --timeout=120s >/dev/null 2>&1 || true

echo
echo "Ambiente pronto! Leia o enunciado.md"
