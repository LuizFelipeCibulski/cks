#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=seccomp-q2
OUT=/opt/course/12/q2
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
W=$(worker_node)

info "Limpando tentativas anteriores..."
ns_fresh "$NS"
rm -f /var/lib/kubelet/seccomp/profiles/block-chmod.json
[ -n "$W" ] && $SSH "$W" "rm -f /var/lib/kubelet/seccomp/profiles/block-chmod.json" >/dev/null 2>&1
rm -rf "$OUT"; mkdir -p "$OUT"

info "Preparando arquivos..."
cat > "$OUT/block-chmod.json" <<'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF

cat > "$OUT/pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened
  namespace: $NS
spec:
  nodeSelector:
    kubernetes.io/hostname: $CPN
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
EOF

echo
ok "Ambiente pronto! Leia o enunciado.md"
