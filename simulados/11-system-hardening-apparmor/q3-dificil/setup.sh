#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=apparmor-q3
OUT=/opt/course/11/q3
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
W=$(worker_node)
T=${W:-$CPN}

on_node() { if [ "$T" = "$CPN" ]; then bash -c "$*"; else $SSH "$T" "$*"; fi; }

if [ -z "$W" ]; then
  info "ATENÇÃO: cluster sem node worker — nesta execução, onde o enunciado diz node01 use '$CPN'."
else
  $SSH "$W" true 2>/dev/null || { echo "Não foi possível acessar '$W' via ssh."; exit 1; }
fi
[ "$(on_node cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ] \
  || { echo "AppArmor não está habilitado no nó $T — questão não aplicável."; exit 1; }

info "Limpando tentativas anteriores..."
ns_fresh "$NS"
kubectl label nodes --all security- >/dev/null 2>&1
for n in "$CPN" ${W:+"$W"}; do
  T0=$T; T=$n
  on_node 'for f in $(grep -ls "profile k8s-deny-upload" /etc/apparmor.d/* 2>/dev/null); do apparmor_parser -R "$f" >/dev/null 2>&1; rm -f "$f"; done
           echo "profile k8s-deny-upload {}" | apparmor_parser -R >/dev/null 2>&1; true'
  T=$T0
done
rm -rf "$OUT"; mkdir -p "$OUT"

info "Preparando perfil e Deployment..."
cat > "$OUT/k8s-deny-uploads" <<'EOF'
#include <tunables/global>

profile k8s-deny-upload flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  file,
  network,
  capability,
  signal,
  unix,

  # o diretório de uploads é somente leitura para o processo
  deny /uploads/ w,
  deny /uploads/** wl,
}
EOF

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: uploader
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: uploader
  template:
    metadata:
      labels:
        app: uploader
    spec:
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: k8s-deny-uploads
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: uploader
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date >> /tmp/heartbeat; sleep 5; done"]
        volumeMounts:
        - name: uploads
          mountPath: /uploads
      volumes:
      - name: uploads
        emptyDir: {}
EOF

echo
kubectl -n "$NS" get pods -o wide 2>/dev/null
echo
ok "Ambiente pronto! Leia o enunciado.md"
