#!/usr/bin/env bash
# Q1 (fácil) - binários com hashes SHA512 fornecidos; um deles foi adulterado.
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

ARCH=$(dpkg --print-architecture 2>/dev/null || echo amd64)
KVER=$(kubelet --version 2>/dev/null | awk '{print $2}')
[ -z "$KVER" ] && KVER=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
[ -z "$KVER" ] && { echo "Não foi possível descobrir a versão do Kubernetes"; exit 1; }

CACHE=/root/cks-cache/bin/$KVER
STATE=/var/lib/cks-sim
D=/opt/course/5/q1
mkdir -p "$CACHE" "$STATE"

fetch_bin() {
  local b=$1
  [ -s "$CACHE/$b" ] && return 0
  info "Baixando $b $KVER de dl.k8s.io ..."
  curl -fsSL --retry 3 -o "$CACHE/$b.part" "https://dl.k8s.io/release/$KVER/bin/linux/$ARCH/$b" \
    && mv "$CACHE/$b.part" "$CACHE/$b" || { echo "Falha ao baixar $b"; exit 1; }
}

info "Limpando tentativas anteriores..."
rm -rf "$D"; mkdir -p "$D"

BINS=(kubectl kubeadm kubelet)
for b in "${BINS[@]}"; do
  fetch_bin "$b"
  cp "$CACHE/$b" "$D/$b"; chmod 755 "$D/$b"
done

# hashes oficiais (calculados sobre os binários baixados de dl.k8s.io)
( cd "$D" && sha512sum "${BINS[@]}" > sha512sums.txt )
cp "$D/sha512sums.txt" "$STATE/05-q1.sums"

# adultera um binário aleatório sem mudar o tamanho
BAD=${BINS[$((RANDOM % ${#BINS[@]}))]}
SIZE=$(stat -c %s "$D/$BAD")
printf 'CKS-TAMPERED' | dd of="$D/$BAD" bs=1 seek=$((SIZE - 8192)) conv=notrunc status=none
echo "$BAD" > "$STATE/05-q1.ans"

echo
echo "Ambiente pronto! Leia o enunciado.md"
