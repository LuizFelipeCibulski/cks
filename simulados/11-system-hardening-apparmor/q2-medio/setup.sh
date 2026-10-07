#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=apparmor-q2
OUT=/opt/course/11/q2
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)

[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ] \
  || { echo "AppArmor não está habilitado no kernel deste nó — questão não aplicável."; exit 1; }

info "Limpando tentativas anteriores..."
ns_fresh "$NS"
for p in k8s-nginx-ro k8s-legacy-audit; do
  [ -f "/etc/apparmor.d/$p" ] && apparmor_parser -R "/etc/apparmor.d/$p" >/dev/null 2>&1
  rm -f "/etc/apparmor.d/$p"
done
rm -rf "$OUT"; mkdir -p "$OUT"

info "Instalando perfis AppArmor..."
cat > /etc/apparmor.d/k8s-legacy-audit <<'EOF'
#include <tunables/global>

profile k8s-legacy-audit flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  file,
  network,
  capability,
  signal,
  unix,
  deny /etc/shadow rwkl,
}
EOF

cat > /etc/apparmor.d/k8s-nginx-ro <<'EOF'
#include <tunables/global>

# Impede que o conteúdo publicado pelo nginx seja alterado (defacement)
profile k8s-nginx-ro flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  file,
  network,
  capability,
  signal,
  unix,

  deny /usr/share/nginx/html/ w,
  deny /usr/share/nginx/html/** wl,
}
EOF

apparmor_parser -r /etc/apparmor.d/k8s-legacy-audit
apparmor_parser -C -r /etc/apparmor.d/k8s-nginx-ro     # carregado em modo complain

info "Criando Deployment web..."
kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      nodeSelector:
        kubernetes.io/hostname: $CPN
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
      - name: logger
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date; sleep 10; done"]
EOF
wait_pods "$NS"

echo
ok "Ambiente pronto! Leia o enunciado.md"
