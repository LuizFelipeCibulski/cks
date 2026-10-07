#!/usr/bin/env bash
# Q2 (médio) - aluno descobre a versão, busca os sha256 oficiais e coloca em quarentena os adulterados.
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

ARCH=$(dpkg --print-architecture 2>/dev/null || echo amd64)
KVER=$(kubelet --version 2>/dev/null | awk '{print $2}')
[ -z "$KVER" ] && KVER=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
[ -z "$KVER" ] && { echo "Não foi possível descobrir a versão do Kubernetes"; exit 1; }

CACHE=/root/cks-cache/bin/$KVER
STATE=/var/lib/cks-sim
D=/opt/course/5/q2
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

BINS=(kubectl kubeadm kubelet kube-proxy)
for b in "${BINS[@]}"; do
  fetch_bin "$b"
  cp "$CACHE/$b" "$D/$b"; chmod 755 "$D/$b"
done
( cd "$CACHE" && sha512sum "${BINS[@]}" > "$STATE/05-q2.sums" )
echo "$KVER" > "$STATE/05-q2.ver"

# escolhe dois binários distintos para adulterar
i=$((RANDOM % 4))
j=$(( (i + 1 + RANDOM % 3) % 4 ))
k=0; while [ "$k" -eq "$i" ] || [ "$k" -eq "$j" ]; do k=$((k + 1)); done

# 1) bytes alterados no meio do arquivo (mesmo tamanho)
SIZE=$(stat -c %s "$D/${BINS[$i]}")
printf 'CKS-TAMPERED' | dd of="$D/${BINS[$i]}" bs=1 seek=$((SIZE / 2)) conv=notrunc status=none
# 2) binário substituído por outro binário (oficial, mas não é o que o nome diz)
cp "$CACHE/${BINS[$k]}" "$D/${BINS[$j]}"; chmod 755 "$D/${BINS[$j]}"

printf '%s\n%s\n' "${BINS[$i]}" "${BINS[$j]}" | sort > "$STATE/05-q2.ans"

echo
echo "Ambiente pronto! Leia o enunciado.md"
