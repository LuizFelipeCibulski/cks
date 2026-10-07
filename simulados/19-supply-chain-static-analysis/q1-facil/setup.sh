#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

command -v jq >/dev/null || { apt-get update -qq >/dev/null; apt-get install -y jq >/dev/null 2>&1; }
install_kubesec
command -v kubesec >/dev/null || { echo "Falha ao instalar kubesec"; exit 1; }

info "Recriando namespace kubesec-lab..."
ns_fresh kubesec-lab

rm -rf /opt/course/19/q1
mkdir -p /opt/course/19/q1
cat > /opt/course/19/q1/pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: legacy-agent
  namespace: kubesec-lab
  labels:
    app: legacy-agent
spec:
  hostPID: true
  hostNetwork: true
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      privileged: true
EOF

echo
echo "Ambiente pronto! Leia o enunciado.md"
