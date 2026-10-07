#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace sec-ctx..."
ns_fresh sec-ctx
rm -rf /opt/course/14/q1 && mkdir -p /opt/course/14/q1
cat > /opt/course/14/q1/pod.yaml <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: sec-ctx
  labels:
    app: secure-app
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
YAML
echo
echo "Ambiente pronto! Leia o enunciado.md"
