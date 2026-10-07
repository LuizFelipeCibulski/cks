#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=upgrade-q2
W=$(worker_node)
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"

abort() { echo -e "${RED}[ABORTADO]${NC} $*"; exit 1; }

[ -n "$W" ] || abort "Esta questão precisa de um node worker (node01). Use o playground CKS do Killercoda com 2 nós."
$SSH "$W" true 2>/dev/null || abort "Não foi possível acessar '$W' via ssh a partir do controlplane."

CPV=$(dpkg-query -W -f='${Version}' kubeadm 2>/dev/null)
[ -n "$CPV" ] || abort "Pacote kubeadm não encontrado no controlplane (instalação não foi via apt?)."
MINOR=$(echo "$CPV" | cut -d. -f1,2)          # ex: 1.35
info "Versão dos pacotes no controlplane: $CPV"

kubectl uncordon "$W" >/dev/null 2>&1

# Garante que o node01 usa o repositório da mesma minor do controlplane
info "Ajustando repositório apt do $W para v$MINOR e atualizando índice..."
$SSH "$W" bash -s -- "$MINOR" >/dev/null 2>&1 <<'EOF'
M=$1
F=$(grep -ls 'pkgs.k8s.io' /etc/apt/sources.list.d/* 2>/dev/null | head -1)
F=${F:-/etc/apt/sources.list.d/kubernetes.list}
mkdir -p /root/cks-backup /etc/apt/keyrings
[ -f /root/cks-backup/kubernetes.list ] || cp -a "$F" /root/cks-backup/kubernetes.list 2>/dev/null
if ! grep -q "core:/stable:/v$M/" "$F" 2>/dev/null; then
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$M/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$M/deb/ /" > "$F"
fi
apt-get update -qq
EOF

WV=$($SSH "$W" "dpkg-query -W -f='\${Version}' kubelet" 2>/dev/null)
if [ -n "$WV" ] && dpkg --compare-versions "$WV" lt "$CPV"; then
  info "$W já está em versão anterior ($WV) — mantendo."
else
  PREV=$($SSH "$W" "apt-cache madison kubelet" 2>/dev/null | awk '{print $3}' | sort -uV | while read -r v; do
           dpkg --compare-versions "$v" lt "$CPV" && echo "$v"; done | tail -1)
  if [ -z "$PREV" ]; then
    abort "Não há versão anterior a $CPV no repositório v$MINOR (o controlplane está na primeira patch da minor).
Não é possível montar o cenário de downgrade do node01 neste ambiente."
  fi
  for p in kubeadm kubelet kubectl; do
    $SSH "$W" "apt-cache madison $p" 2>/dev/null | awk '{print $3}' | grep -qx "$PREV" \
      || abort "Pacote $p=$PREV não disponível no $W."
  done
  info "Fazendo downgrade de kubeadm/kubelet/kubectl no $W para $PREV (pode levar ~1 min)..."
  $SSH "$W" bash -s -- "$PREV" <<'EOF' >/dev/null 2>&1 || abort "Falha no downgrade dos pacotes no node01."
set -e
V=$1
apt-mark unhold kubeadm kubelet kubectl >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --allow-downgrades --allow-change-held-packages \
  kubeadm="$V" kubelet="$V" kubectl="$V"
apt-mark hold kubeadm kubelet kubectl >/dev/null
systemctl daemon-reload
systemctl restart kubelet
EOF
fi

info "Aguardando $W ficar Ready..."
kubectl wait --for=condition=Ready node/"$W" --timeout=180s >/dev/null 2>&1

ns_fresh "$NS"
kubectl -n "$NS" create deployment api --image=nginx:1.27-alpine --replicas=2 >/dev/null
wait_pods "$NS"

echo
kubectl get nodes
echo
ok "Ambiente pronto! Leia o enunciado.md"
