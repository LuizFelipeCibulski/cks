#!/usr/bin/env bash
# Helpers extras da revisão final. Uso: source "$D/../_lib.sh"
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml

falco_svc() {
  local s
  for s in falco-modern-bpf falco-bpf falco-kmod falco-custom falco; do
    systemctl is-active --quiet "$s" 2>/dev/null && { echo "$s"; return; }
  done
  for s in falco-modern-bpf falco-bpf falco-kmod; do
    systemctl cat "$s.service" >/dev/null 2>&1 && { echo "$s"; return; }
  done
  echo falco-modern-bpf
}

# Deixa o Falco com regras locais e falco.yaml originais
falco_reset() {
  install_falco
  command -v falco >/dev/null || { echo "Falha ao instalar o Falco"; exit 1; }
  mkdir -p /root/cks-backup
  local L=/etc/falco/falco_rules.local.yaml
  if [ ! -f /root/cks-backup/falco_rules.local.yaml ]; then
    if [ -f "$L" ]; then cp -a "$L" /root/cks-backup/falco_rules.local.yaml
    else printf '# Your custom rules!\n' > /root/cks-backup/falco_rules.local.yaml; fi
  fi
  [ -f /root/cks-backup/falco.yaml ] || cp -a /etc/falco/falco.yaml /root/cks-backup/falco.yaml
  cp -a /root/cks-backup/falco_rules.local.yaml "$L"
  cp -a /root/cks-backup/falco.yaml /etc/falco/falco.yaml
  local SVC; SVC=$(falco_svc)
  info "Reiniciando o Falco ($SVC)..."
  systemctl enable "$SVC" >/dev/null 2>&1
  systemctl restart "$SVC"; sleep 8
  systemctl is-active --quiet "$SVC" || { echo "Falco não subiu: journalctl -u $SVC"; exit 1; }
}

# Volta o kube-apiserver para o manifest original (guardado em /root/cks-backup)
apiserver_reset() {
  backup_manifest kube-apiserver.yaml
  if ! cmp -s /root/cks-backup/kube-apiserver.yaml "$MANIFEST"; then
    info "Restaurando o kube-apiserver original..."
    cp -a /root/cks-backup/kube-apiserver.yaml "$MANIFEST"
    sleep 20
  fi
  wait_apiserver || exit 1
}

require_cilium() {
  kubectl get crd ciliumnetworkpolicies.cilium.io >/dev/null 2>&1 || { echo "Cilium não encontrado no cluster"; exit 1; }
}

has_internet() { curl -s -o /dev/null -m 5 https://example.com; }

etcd_get() {
  local c="--endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key"
  if command -v etcdctl >/dev/null; then
    ETCDCTL_API=3 etcdctl $c get "$1"
  else
    crictl exec "$(crictl ps --name etcd -q | head -1)" etcdctl $c get "$1"
  fi
}
