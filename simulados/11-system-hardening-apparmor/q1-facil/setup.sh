#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=apparmor-q1
OUT=/opt/course/11/q1
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)

[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" = "Y" ] \
  || { echo "AppArmor não está habilitado no kernel deste nó — questão não aplicável."; exit 1; }
command -v apparmor_parser >/dev/null || { echo "apparmor_parser não encontrado (instale o pacote apparmor)."; exit 1; }

info "Limpando tentativas anteriores..."
ns_fresh "$NS"
for f in /etc/apparmor.d/k8s-deny-write "$OUT/k8s-deny-write"; do
  [ -f "$f" ] && apparmor_parser -R "$f" >/dev/null 2>&1
done
rm -f /etc/apparmor.d/k8s-deny-write
rm -rf "$OUT"; mkdir -p "$OUT"

info "Preparando arquivos..."
cat > "$OUT/k8s-deny-write" <<'EOF'
#include <tunables/global>

profile k8s-deny-write flags=(attach_disconnected) {
  #include <abstractions/base>

  file,

  # nega escrita em qualquer arquivo
  deny /** w,
}
EOF

cat > "$OUT/pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: writer
  namespace: $NS
spec:
  nodeName: $CPN
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo iniciado; sleep 1d"]
EOF

echo
ok "Ambiente pronto! Leia o enunciado.md"
