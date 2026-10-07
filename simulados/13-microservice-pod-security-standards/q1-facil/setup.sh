#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace team-blue..."
ns_fresh team-blue
rm -rf /opt/course/13/q1 && mkdir -p /opt/course/13/q1

kubectl -n team-blue run inventory --image=nginx:1.27-alpine --labels=app=inventory >/dev/null

cat > /opt/course/13/q1/pod.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: node-debugger
  namespace: team-blue
spec:
  containers:
  - name: debugger
    image: busybox:1.36
    command: ["sleep", "1d"]
    securityContext:
      privileged: true
YAML

wait_pods team-blue
echo
echo "Ambiente pronto! Leia o enunciado.md"
