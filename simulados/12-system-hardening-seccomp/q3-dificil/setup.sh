#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

NS=seccomp-q3
OUT=/opt/course/12/q3
SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
CPN=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers -o custom-columns=N:.metadata.name | head -1)
W=$(worker_node)
T=${W:-$CPN}

run_on_t() {  # executa o script do stdin no nó alvo
  if [ "$T" = "$CPN" ]; then bash -s; else $SSH "$T" bash -s; fi
}

if [ -z "$W" ]; then
  info "ATENÇÃO: cluster sem node worker — nesta execução, onde o enunciado diz node01 use '$CPN'."
else
  $SSH "$W" true 2>/dev/null || { echo "Não foi possível acessar '$W' via ssh."; exit 1; }
fi

info "Restaurando a configuração original do kubelet em $T (backup em /root/cks-backup)..."
run_on_t <<'EOF'
C=/var/lib/kubelet/config.yaml
B=/root/cks-backup/kubelet-config.yaml
mkdir -p /root/cks-backup
CHANGED=0
if [ -f "$B" ]; then
  cmp -s "$B" "$C" || { cp -a "$B" "$C"; CHANGED=1; }
else
  cp -a "$C" "$B"
fi
# o cenário exige seccompDefault desligado no início
if grep -Eq '^seccompDefault:[[:space:]]*true' "$C"; then
  sed -i '/^seccompDefault:/d' "$C"; CHANGED=1
fi
if grep -q -- '--seccomp-default' /var/lib/kubelet/kubeadm-flags.env 2>/dev/null; then
  sed -i 's/ *--seccomp-default\(=true\)\?//' /var/lib/kubelet/kubeadm-flags.env; CHANGED=1
fi
rm -f /var/lib/kubelet/seccomp/profiles/no-mkdir.json
if [ "$CHANGED" = 1 ]; then systemctl restart kubelet; fi
EOF
# perfil também não deve existir em outros nós
for n in $(kubectl get nodes --no-headers -o custom-columns=N:.metadata.name); do
  [ "$n" = "$T" ] && continue
  if [ "$n" = "$CPN" ]; then rm -f /var/lib/kubelet/seccomp/profiles/no-mkdir.json
  else $SSH "$n" "rm -f /var/lib/kubelet/seccomp/profiles/no-mkdir.json" >/dev/null 2>&1; fi
done
kubectl wait --for=condition=Ready node/"$T" --timeout=120s >/dev/null 2>&1

info "Criando cenário..."
ns_fresh "$NS"
rm -rf "$OUT"; mkdir -p "$OUT"

cat > "$OUT/no-mkdir.json" <<'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": [
    "SCMP_ARCH_X86_64",
    "SCMP_ARCH_X86",
    "SCMP_ARCH_X32"
  ],
  "syscalls": [
    {
      "names": ["mkdir", "mkdirat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF

kubectl apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: builder
  namespace: $NS
spec:
  replicas: 2
  selector:
    matchLabels:
      app: builder
  template:
    metadata:
      labels:
        app: builder
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: builder
        image: busybox:1.36
        command: ["sh", "-c", "sleep 1d"]
---
apiVersion: v1
kind: Pod
metadata:
  name: plain
  namespace: $NS
spec:
  nodeName: $T
  containers:
  - name: plain
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
EOF
wait_pods "$NS"

echo
ok "Ambiente pronto! Leia o enunciado.md"
