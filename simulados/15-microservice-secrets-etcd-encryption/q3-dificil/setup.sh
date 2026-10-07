#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests/kube-apiserver.yaml
B=/root/cks-backup/kube-apiserver.yaml
ENC=/etc/kubernetes/etcd/ec.yaml

restart_apiserver_container() {
  local id; id=$(crictl ps -q --name kube-apiserver 2>/dev/null | head -1)
  [ -n "$id" ] && crictl stop "$id" >/dev/null 2>&1
  sleep 10
  wait_apiserver
}

install_etcdctl() {
  command -v etcdctl >/dev/null && return 0
  info "Instalando etcdctl..."
  local img v arch
  img=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}')
  v=${img##*:}; v=${v%%-*}; [ -n "$v" ] || v=3.5.21
  case $(uname -m) in aarch64) arch=arm64 ;; *) arch=amd64 ;; esac
  curl -sSL "https://github.com/etcd-io/etcd/releases/download/v${v}/etcd-v${v}-linux-${arch}.tar.gz" | tar xz -C /tmp \
    && mv "/tmp/etcd-v${v}-linux-${arch}/etcdctl" /usr/local/bin/ && rm -rf "/tmp/etcd-v${v}-linux-${arch}"
  command -v etcdctl >/dev/null || echo "AVISO: não foi possível instalar o etcdctl; use 'kubectl -n kube-system exec etcd-<node> -- etcdctl ...'"
}

# Se uma tentativa anterior cifrou os dados, decifra antes de restaurar o apiserver original
# (senão o apiserver original não conseguiria ler os Secrets cifrados).
decrypt_previous_attempt() {
  [ -f "$B" ] || return 0
  grep -q -- '--encryption-provider-config' "$B" && return 0          # o original já tinha criptografia: não mexe
  local cfg; cfg=$(grep -oE -- '--encryption-provider-config=[^ "]+' "$M" | head -1 | cut -d= -f2-)
  [ -n "$cfg" ] && [ -f "$cfg" ] || return 0
  if ! kubectl get --raw=/readyz >/dev/null 2>&1; then
    info "kube-apiserver fora do ar com a config da tentativa anterior; restaurando sem decifrar (Secrets cifrados podem ficar ilegíveis)"
    return 0
  fi
  info "Decifrando Secrets cifrados pela tentativa anterior (identity primeiro)..."
  mkdir -p /root/cks-backup
  cp -a "$cfg" "/root/cks-backup/ec-tentativa-anterior-$(date +%s).yaml"
  awk '
    /^[[:space:]]*-[[:space:]]*identity:[[:space:]]*\{\}[[:space:]]*(#.*)?$/ { next }
    { print }
    /^[[:space:]]*providers:[[:space:]]*$/ {
      if ((getline nxt) > 0) {
        if (nxt ~ /identity:/) { print nxt }
        else { ind=nxt; sub(/-.*/, "", ind); print ind "- identity: {}"; print nxt }
      }
    }' "$cfg" > "$cfg.tmp" && cat "$cfg.tmp" > "$cfg" && rm -f "$cfg.tmp"
  restart_apiserver_container || return 0
  kubectl get secrets -A -o json | kubectl replace -f - >/dev/null 2>&1
  grep -q configmaps "$cfg" && kubectl get configmaps -A -o json | kubectl replace -f - >/dev/null 2>&1
  return 0
}

install_etcdctl
decrypt_previous_attempt
if [ -f "$B" ] && ! cmp -s "$B" "$M"; then
  info "Restaurando kube-apiserver.yaml original de /root/cks-backup..."
  cp "$B" "$M"
  sleep 20
fi
wait_apiserver || exit 1
backup_manifest kube-apiserver.yaml

info "Recriando namespace bank e Secrets..."
ns_fresh bank
kubectl -n bank create secret generic bank-creds --from-literal=user=bank-admin --from-literal=pass='C0fr3-F0rt3!' >/dev/null
kubectl -n bank create secret generic bank-api-key --from-literal=key=ak_live_51H8xQ2 >/dev/null
kubectl -n default delete secret cks-legacy-token --ignore-not-found >/dev/null
kubectl -n default create secret generic cks-legacy-token --from-literal=token=legacy-0001 >/dev/null

rm -rf /opt/course/15/q3 && mkdir -p /opt/course/15/q3
mkdir -p /etc/kubernetes/etcd
cat > "$ENC" <<'YAML'
# Rascunho - criptografia de Secrets no etcd (NÃO TERMINADO)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - identity: {}
      - aescbc:
          keys:
            - name: key1
              secret: bWluaGEtY2hhdmU=
YAML
echo
echo "Ambiente pronto! Leia o enunciado.md"
