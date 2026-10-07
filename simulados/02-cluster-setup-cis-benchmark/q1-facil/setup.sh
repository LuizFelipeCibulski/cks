#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
B=/root/cks-backup

# Espera até que o processo <bin> esteja rodando com a string <padrão> na linha de comando
wait_flag() {
  for _ in $(seq 1 90); do
    ps -ww -eo args | grep -E "^$1( |$)" | grep -q -- "$2" && return 0
    sleep 2
  done
  echo "Timeout aguardando $1 com '$2'"; return 1
}

# Planta --profiling=true num manifest estático partindo SEMPRE do backup original
plant_profiling() {
  local file=$1 bin=$2 tmp
  backup_manifest "$file"
  tmp=$(mktemp)
  cp -a "$B/$file" "$tmp"
  sed -i '/^[[:space:]]*- --profiling=/d' "$tmp"
  sed -i "s/^\([[:space:]]*\)- $bin\$/&\n\1- --profiling=true/" "$tmp"
  cp "$tmp" "$M/$file"   # cp preserva o inode/permissões do destino
  rm -f "$tmp"
}

info "Limpando tentativas anteriores..."
rm -rf /opt/course/02/q1
mkdir -p /opt/course/02/q1

install_kube_bench
command -v kube-bench >/dev/null || { echo "Falha ao instalar kube-bench"; exit 1; }

# Desfaz alterações de outras questões deste componente no apiserver/etcd (se houver backup)
for f in kube-apiserver.yaml etcd.yaml; do
  [ -f "$B/$f" ] && ! cmp -s "$B/$f" "$M/$f" && cp "$B/$f" "$M/$f"
done

info "Preparando kube-controller-manager e kube-scheduler..."
plant_profiling kube-controller-manager.yaml kube-controller-manager
plant_profiling kube-scheduler.yaml kube-scheduler

wait_flag kube-controller-manager '--profiling=true'
wait_flag kube-scheduler '--profiling=true'
wait_apiserver
kubectl -n kube-system wait --for=condition=Ready pod -l 'component in (kube-controller-manager,kube-scheduler)' --timeout=120s >/dev/null 2>&1 || true

echo
echo "Ambiente pronto! Leia o enunciado.md"
