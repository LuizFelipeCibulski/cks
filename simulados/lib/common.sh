#!/usr/bin/env bash
# Funções compartilhadas pelos setup.sh / verify.sh dos simulados.
# Uso: source "$(dirname "$0")/../../lib/common.sh"

export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
[ -f "$HOME/.kube/config" ] && export KUBECONFIG="$HOME/.kube/config"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${YELLOW}[setup]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; FAILED=1; }
FAILED=0

require_root() {
  if [ "$(id -u)" -ne 0 ]; then echo "Execute como root (sudo -i)"; exit 1; fi
}

require_controlplane() {
  if [ ! -d /etc/kubernetes/manifests ]; then
    echo "Execute no node controlplane (kubeadm)"; exit 1
  fi
}

# Espera o kube-apiserver responder (útil depois de editar manifests estáticos)
wait_apiserver() {
  info "Aguardando kube-apiserver..."
  for _ in $(seq 1 90); do
    kubectl get --raw=/readyz >/dev/null 2>&1 && { ok "apiserver pronto"; return 0; }
    sleep 2
  done
  echo "apiserver não respondeu em 3 minutos"; return 1
}

# Backup de um arquivo uma única vez (preserva o original para reset)
backup_once() {
  local f=$1
  [ -f "$f" ] && [ ! -f "$f.cks-orig" ] && cp -a "$f" "$f.cks-orig"
  return 0
}

# Restaura todos os backups feitos por backup_once em um diretório
restore_backups() {
  local dir=${1:-/etc/kubernetes}
  find "$dir" -name '*.cks-orig' 2>/dev/null | while read -r b; do
    cp -a "$b" "${b%.cks-orig}"
  done
}

# Backups de manifests estáticos NUNCA ficam em /etc/kubernetes/manifests (o kubelet tentaria subir)
backup_manifest() {
  mkdir -p /root/cks-backup
  local f=/etc/kubernetes/manifests/$1
  [ -f "/root/cks-backup/$1" ] || cp -a "$f" "/root/cks-backup/$1"
}

ns_fresh() {
  kubectl delete ns "$1" --ignore-not-found --wait=true >/dev/null 2>&1
  kubectl create ns "$1" >/dev/null
}

wait_pods() {
  # wait_pods <namespace> [selector]
  kubectl -n "$1" wait --for=condition=Ready pod ${2:+-l "$2"} --all --timeout=180s >/dev/null 2>&1 || true
}

worker_node() {
  kubectl get nodes --no-headers -l '!node-role.kubernetes.io/control-plane' -o custom-columns=N:.metadata.name 2>/dev/null | head -1
}

install_trivy() {
  command -v trivy >/dev/null && return 0
  info "Instalando trivy..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin >/dev/null
}

install_kubesec() {
  command -v kubesec >/dev/null && return 0
  info "Instalando kubesec..."
  local v=v2.14.2
  curl -sSL "https://github.com/controlplaneio/kubesec/releases/download/${v}/kubesec_linux_amd64.tar.gz" | tar xz -C /usr/local/bin kubesec
}

install_kube_bench() {
  command -v kube-bench >/dev/null && return 0
  info "Instalando kube-bench..."
  local v=0.10.6
  curl -sSL -o /tmp/kb.deb "https://github.com/aquasecurity/kube-bench/releases/download/v${v}/kube-bench_${v}_linux_amd64.deb" \
    && apt-get install -y /tmp/kb.deb >/dev/null 2>&1
}

install_falco() {
  command -v falco >/dev/null && return 0
  info "Instalando falco (pode demorar ~1-2 min)..."
  curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" > /etc/apt/sources.list.d/falcosecurity.list
  apt-get update -qq >/dev/null
  FALCO_FRONTEND=noninteractive FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco >/dev/null 2>&1
  systemctl enable --now falco-modern-bpf.service >/dev/null 2>&1 || true
}

finish() {
  echo
  if [ "$FAILED" -eq 0 ]; then echo -e "${GREEN}Resultado: APROVADO${NC}"; else echo -e "${RED}Resultado: ainda há itens pendentes${NC}"; exit 1; fi
}
