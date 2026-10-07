#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=upgrade-q3
OUT=/opt/course/09/q3
STATE=/root/cks-backup/09-q3-target
W=$(worker_node)
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"

abort() { echo -e "${RED}[ABORTADO]${NC} $*"; exit 1; }

# Executa o script lido do stdin no nó indicado (local se vazio)
run_on() {
  local n=$1; shift
  if [ -z "$n" ]; then bash -s -- "$@"; else $SSH "$n" bash -s -- "$@"; fi
}

# Script que aponta o repositório pkgs.k8s.io para a minor $1 e roda apt-get update
REPO_SCRIPT='
M=$1
F=$(grep -ls "pkgs.k8s.io" /etc/apt/sources.list.d/* 2>/dev/null | head -1)
F=${F:-/etc/apt/sources.list.d/kubernetes.list}
mkdir -p /root/cks-backup /etc/apt/keyrings
[ -f /root/cks-backup/kubernetes.list ] || cp -a "$F" /root/cks-backup/kubernetes.list 2>/dev/null
if ! grep -q "core:/stable:/v$M/" "$F" 2>/dev/null; then
  curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$M/deb/Release.key" | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || exit 1
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$M/deb/ /" > "$F"
fi
apt-get update -qq >/dev/null 2>&1
'
set_repo() { echo "$REPO_SCRIPT" | run_on "$1" "$2"; }   # set_repo <node|""> <minor>

if [ -n "$W" ]; then
  $SSH "$W" true 2>/dev/null || abort "Não foi possível acessar '$W' via ssh."
  kubectl uncordon "$W" >/dev/null 2>&1
else
  info "ATENÇÃO: cluster sem node worker — apenas o controlplane será cobrado."
fi
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
kubectl uncordon "$CPN" >/dev/null 2>&1

CUR=$(kubectl get --raw /version 2>/dev/null | tr ',{}' '\n\n\n' | grep '"gitVersion"' | sed -E 's/.*"v([^"]+)".*/\1/')
[ -n "$CUR" ] || abort "Não foi possível obter a versão do kube-apiserver."
CURMIN=$(echo "$CUR" | cut -d. -f1,2)
info "Versão atual do cluster: v$CUR"

TARGET=""
if [ -f "$STATE" ]; then
  T=$(cat "$STATE")
  if dpkg --compare-versions "$CUR" lt "$T"; then
    TARGET=$T; info "Reaproveitando alvo definido anteriormente: v$TARGET"
  else
    info "Cluster já está em v$CUR (alvo anterior v$T atingido) — calculando novo alvo."
  fi
fi

latest_in_repo() {  # imprime a maior versão upstream (X.Y.Z) do kubeadm no repo configurado localmente
  apt-cache madison kubeadm 2>/dev/null | awk '{print $3}' | sed 's/-.*//' | sort -uV | tail -1
}

if [ -z "$TARGET" ]; then
  MAJ=${CURMIN%%.*}; MIN=${CURMIN#*.}
  NEXT="$MAJ.$((MIN+1))"
  if curl -fsSL -o /dev/null "https://pkgs.k8s.io/core:/stable:/v$NEXT/deb/Release" 2>/dev/null; then
    info "Repositório v$NEXT existe — o alvo será a última patch de v$NEXT (upgrade de minor)."
    set_repo "" "$NEXT" || abort "Falha ao configurar o repositório v$NEXT."
    TARGET=$(latest_in_repo)
    case "$TARGET" in "$NEXT".*) ;; *) TARGET="";; esac
  fi
  if [ -z "$TARGET" ]; then
    info "Sem minor nova publicada — procurando patch mais nova em v$CURMIN."
    set_repo "" "$CURMIN" || abort "Falha ao configurar o repositório v$CURMIN."
    TARGET=$(latest_in_repo)
  fi
  [ -n "$TARGET" ] || abort "Não foi possível consultar o repositório pkgs.k8s.io (sem internet?)."
  dpkg --compare-versions "$TARGET" gt "$CUR" \
    || abort "O cluster já está na versão mais nova disponível (v$CUR). Não há upgrade possível neste ambiente."
fi

TMIN=$(echo "$TARGET" | cut -d. -f1,2)
info "Alvo: v$TARGET — ajustando repositório apt v$TMIN nos nós..."
set_repo "" "$TMIN" || abort "Falha ao ajustar repo no controlplane."
[ -n "$W" ] && { set_repo "$W" "$TMIN" || abort "Falha ao ajustar repo no $W."; }
apt-cache madison kubeadm | awk '{print $3}' | grep -q "^$TARGET-" \
  || abort "kubeadm $TARGET não encontrado no repositório do controlplane."

mkdir -p /root/cks-backup "$OUT"
echo "$TARGET" > "$STATE"
echo "v$TARGET" > "$OUT/target-version"

# garante que os pacotes estão em hold (como numa instalação kubeadm padrão)
apt-mark hold kubeadm kubelet kubectl >/dev/null 2>&1
[ -n "$W" ] && $SSH "$W" "apt-mark hold kubeadm kubelet kubectl" >/dev/null 2>&1

info "Criando workload crítico em $NS..."
ns_fresh "$NS"
kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: critical-app
  template:
    metadata:
      labels:
        app: critical-app
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: app
        image: httpd:2.4-alpine
EOF
wait_pods "$NS"

echo
kubectl get nodes
echo
info "Versão alvo gravada em $OUT/target-version: v$TARGET"
ok "Ambiente pronto! Leia o enunciado.md"
