#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
B=/root/cks-backup
KCFG=$(ps -ww -eo args | grep -E '^(/usr/bin/)?kubelet ' | head -1 | tr ' ' '\n' | grep -- '^--config=' | cut -d= -f2-)
KCFG=${KCFG:-/var/lib/kubelet/config.yaml}
DEF=/etc/default/kubelet

wait_flag() {
  for _ in $(seq 1 90); do
    ps -ww -eo args | grep -E "^$1( |$)" | grep -q -- "$2" && return 0
    sleep 2
  done
  echo "Timeout aguardando $1 com '$2'"; return 1
}

info "Limpando tentativas anteriores..."
rm -rf /opt/course/02/q3
mkdir -p /opt/course/02/q3 "$B"

install_kube_bench
command -v kube-bench >/dev/null || { echo "Falha ao instalar kube-bench"; exit 1; }

# Restaura manifests que outras questões deste componente possam ter alterado
for f in kube-apiserver.yaml kube-scheduler.yaml; do
  [ -f "$B/$f" ] && ! cmp -s "$B/$f" "$M/$f" && cp "$B/$f" "$M/$f"
done

# ---------- kubelet: backup / restauração do estado original ----------
[ -f "$B/kubelet-config.yaml" ] || cp -a "$KCFG" "$B/kubelet-config.yaml"
if [ ! -f "$B/default-kubelet" ] && [ ! -f "$B/default-kubelet.absent" ]; then
  if [ -f "$DEF" ]; then cp -a "$DEF" "$B/default-kubelet"; else touch "$B/default-kubelet.absent"; fi
fi
cp -a "$B/kubelet-config.yaml" "$KCFG"
if [ -f "$B/default-kubelet" ]; then cp -a "$B/default-kubelet" "$DEF"; else rm -f "$DEF"; fi
chown root:root "$KCFG" /etc/kubernetes/kubelet.conf
chmod 600 /etc/kubernetes/kubelet.conf

info "Preparando kubelet do controlplane..."
# config.yaml inseguro
sed -i '/^  anonymous:/{n;s/enabled: false/enabled: true/}' "$KCFG"
sed -i 's/^  mode: Webhook/  mode: AlwaysAllow/' "$KCFG"
sed -i '/^readOnlyPort:/d' "$KCFG"
echo 'readOnlyPort: 10255' >> "$KCFG"
chmod 666 "$KCFG"
chmod 644 /etc/kubernetes/kubelet.conf
# flag extra (sobrescreve o config file!) via /etc/default/kubelet
EXTRA=""
[ -f "$DEF" ] && EXTRA=$( . "$DEF" >/dev/null 2>&1; echo "${KUBELET_EXTRA_ARGS:-}")
[ -f "$DEF" ] && sed -i '/^KUBELET_EXTRA_ARGS=/d' "$DEF"
echo "KUBELET_EXTRA_ARGS=\"${EXTRA:+$EXTRA }--anonymous-auth=true\"" >> "$DEF"

systemctl daemon-reload
systemctl restart kubelet

# ---------- etcd ----------
info "Preparando etcd e kube-controller-manager..."
backup_manifest etcd.yaml
tmp=$(mktemp)
cp -a "$B/etcd.yaml" "$tmp"
sed -i 's/- --client-cert-auth=true/- --client-cert-auth=false/' "$tmp"
cp "$tmp" "$M/etcd.yaml"

# ---------- kube-controller-manager ----------
backup_manifest kube-controller-manager.yaml
cp -a "$B/kube-controller-manager.yaml" "$tmp"
sed -i 's/--use-service-account-credentials=true/--use-service-account-credentials=false/' "$tmp"
grep -q -- '--use-service-account-credentials' "$tmp" || \
  sed -i 's/^\([[:space:]]*\)- kube-controller-manager$/&\n\1- --use-service-account-credentials=false/' "$tmp"
cp "$tmp" "$M/kube-controller-manager.yaml"
rm -f "$tmp"

sleep 5
wait_flag etcd '--client-cert-auth=false'
wait_flag kube-controller-manager '--use-service-account-credentials=false'
wait_apiserver
for _ in $(seq 1 60); do
  curl -sk -o /dev/null -m 2 https://127.0.0.1:10250/healthz && break; sleep 2
done
kubectl wait --for=condition=Ready node -l node-role.kubernetes.io/control-plane --timeout=120s >/dev/null 2>&1 || true
kubectl -n kube-system wait --for=condition=Ready pod -l tier=control-plane --timeout=120s >/dev/null 2>&1 || true

echo
echo "Ambiente pronto! Leia o enunciado.md"
