#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

info "Limpando tentativas anteriores..."
kubectl delete validatingadmissionpolicybinding require-readonly-rootfs-binding --ignore-not-found >/dev/null 2>&1
kubectl delete validatingadmissionpolicy require-readonly-rootfs --ignore-not-found >/dev/null 2>&1
rm -rf /opt/course/24/q3
mkdir -p /opt/course/24/q3
for ns in orion pegasus lyra; do ns_fresh "$ns"; done

cat > /opt/course/24/q3/frontend.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: lyra
  labels: {app: frontend}
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
  - name: log-agent
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /tmp/agent.log; sleep 5; done"]
    securityContext:
      allowPrivilegeEscalation: false
EOF

info "Criando Pods em orion, pegasus e lyra..."
kubectl apply -f /opt/course/24/q3/frontend.yaml >/dev/null
cat <<'EOF' | kubectl apply -f - >/dev/null
# ---------------- orion ----------------
apiVersion: v1
kind: Pod
metadata: {name: api, namespace: orion, labels: {app: api}}
spec:
  securityContext: {runAsUser: 1000}
  containers:
  - name: api
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true}
---
apiVersion: v1
kind: Pod
metadata: {name: cache, namespace: orion, labels: {app: cache}}
spec:
  securityContext: {runAsUser: 1000}
  containers:
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {allowPrivilegeEscalation: false}
---
apiVersion: v1
kind: Pod
metadata: {name: scheduler, namespace: orion, labels: {app: scheduler}}
spec:
  securityContext: {runAsUser: 2000, runAsNonRoot: true}
  initContainers:
  - name: init
    image: busybox:1.36
    command: ["sh", "-c", "echo preparing; sleep 1"]
  containers:
  - name: scheduler
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true}
---
# ---------------- pegasus ----------------
apiVersion: v1
kind: Pod
metadata: {name: worker, namespace: pegasus, labels: {app: worker}}
spec:
  securityContext: {runAsUser: 1000}
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true, privileged: true}
---
apiVersion: v1
kind: Pod
metadata: {name: metrics, namespace: pegasus, labels: {app: metrics}}
spec:
  containers:
  - name: metrics
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext:
      readOnlyRootFilesystem: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
---
apiVersion: v1
kind: Pod
metadata: {name: batch, namespace: pegasus, labels: {app: batch}}
spec:
  securityContext: {runAsUser: 1000}
  containers:
  - name: batch
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true, runAsUser: 0}
---
apiVersion: v1
kind: Pod
metadata: {name: db, namespace: pegasus, labels: {app: db}}
spec:
  securityContext: {runAsUser: 999, fsGroup: 999}
  containers:
  - name: db
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /data/db.log; sleep 10; done"]
    securityContext: {readOnlyRootFilesystem: true}
    volumeMounts:
    - {name: data, mountPath: /data}
  volumes:
  - {name: data, emptyDir: {}}
---
# ---------------- lyra ----------------
apiVersion: v1
kind: Pod
metadata: {name: backend, namespace: lyra, labels: {app: backend}}
spec:
  containers:
  - name: backend
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true, allowPrivilegeEscalation: false}
---
apiVersion: v1
kind: Pod
metadata: {name: static, namespace: lyra, labels: {app: static}}
spec:
  securityContext: {runAsUser: 101, runAsNonRoot: true}
  containers:
  - name: static
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    securityContext: {readOnlyRootFilesystem: true, allowPrivilegeEscalation: false}
EOF

for ns in orion pegasus lyra; do wait_pods "$ns"; done

echo
ok "Ambiente pronto! Leia o enunciado.md"
