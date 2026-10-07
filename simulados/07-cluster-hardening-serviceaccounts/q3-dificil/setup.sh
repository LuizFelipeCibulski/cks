#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

info "Recriando namespace observer..."
ns_fresh observer
rm -rf /opt/course/7/q3; mkdir -p /opt/course/7/q3

kubectl -n observer create deployment web --image=nginx:1.27-alpine >/dev/null
kubectl -n observer create deployment cache --image=redis:7.4-alpine >/dev/null
# permissão excessiva herdada pela SA default
kubectl -n observer create rolebinding default-edit --clusterrole=edit --serviceaccount=observer:default >/dev/null

# tentativa "quebrada" do colega
cat > /opt/course/7/q3/pod-lister.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pod-lister
  namespace: observer
  labels:
    app: pod-lister
spec:
  containers:
  - name: lister
    image: curlimages/curl:8.10.1
    command: ["sh", "-c", "sleep 1d"]
    volumeMounts:
    - name: api-token
      mountPath: /var/run/secrets/tokens
      readOnly: true
  volumes:
  - name: api-token
    projected:
      sources:
      - serviceAccountToken:
          path: token
          audience: vault
          expirationSeconds: 3600
EOF
kubectl apply -f /opt/course/7/q3/pod-lister.yaml >/dev/null
wait_pods observer

echo
echo "Ambiente pronto! Leia o enunciado.md"
