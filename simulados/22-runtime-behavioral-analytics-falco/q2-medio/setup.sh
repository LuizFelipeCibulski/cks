#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

falco_svc() {
  local s
  for s in falco-modern-bpf falco-bpf falco-kmod falco-custom falco; do
    systemctl is-active --quiet "$s" 2>/dev/null && { echo "$s"; return; }
  done
  for s in falco-modern-bpf falco-bpf falco-kmod; do
    systemctl cat "$s.service" >/dev/null 2>&1 && { echo "$s"; return; }
  done
  echo falco-modern-bpf
}

# --- Falco instalado, com regras locais limpas e rodando ---
install_falco
command -v falco >/dev/null || { echo "Falha ao instalar o Falco"; exit 1; }
mkdir -p /root/cks-backup
LOCAL=/etc/falco/falco_rules.local.yaml
if [ ! -f /root/cks-backup/falco_rules.local.yaml ]; then
  if [ -f "$LOCAL" ]; then cp -a "$LOCAL" /root/cks-backup/falco_rules.local.yaml
  else printf '# Your custom rules!\n' > /root/cks-backup/falco_rules.local.yaml; fi
fi
cp -a /root/cks-backup/falco_rules.local.yaml "$LOCAL"

SVC=$(falco_svc)
info "Reiniciando o Falco ($SVC)..."
systemctl enable "$SVC" >/dev/null 2>&1
systemctl restart "$SVC"
sleep 8
systemctl is-active --quiet "$SVC" || { echo "Falco não subiu: journalctl -u $SVC"; exit 1; }

# --- Workloads ---
rm -rf /opt/course/22/q2
mkdir -p /opt/course/22/q2
for ns in shop billing analytics; do ns_fresh "$ns"; done

info "Criando Deployments..."
cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata: {name: frontend, namespace: shop, labels: {app: frontend}}
spec:
  replicas: 2
  selector: {matchLabels: {app: frontend}}
  template:
    metadata: {labels: {app: frontend}}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: cart, namespace: shop, labels: {app: cart}}
spec:
  replicas: 1
  selector: {matchLabels: {app: cart}}
  template:
    metadata: {labels: {app: cart}}
    spec:
      containers:
      - name: cart
        image: busybox:1.36
        command: ["sh", "-c", "while true; do date > /tmp/heartbeat; sleep 10; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: invoice, namespace: billing, labels: {app: invoice}}
spec:
  replicas: 1
  selector: {matchLabels: {app: invoice}}
  template:
    metadata: {labels: {app: invoice}}
    spec:
      containers:
      - name: invoice
        image: busybox:1.36
        command: ["sh", "-c", "while true; do cat /etc/shadow > /dev/null; sleep 10; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: payments, namespace: billing, labels: {app: payments}}
spec:
  replicas: 2
  selector: {matchLabels: {app: payments}}
  template:
    metadata: {labels: {app: payments}}
    spec:
      containers:
      - name: payments
        image: httpd:2.4-alpine
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: collector, namespace: analytics, labels: {app: collector}}
spec:
  replicas: 1
  selector: {matchLabels: {app: collector}}
  template:
    metadata: {labels: {app: collector}}
    spec:
      containers:
      - name: collector
        image: busybox:1.36
        command:
        - sh
        - -c
        - |
          cp /bin/busybox /tmp/xmrig
          while true; do
            /tmp/xmrig > /dev/null 2>&1
            find /root /home -name id_rsa > /dev/null 2>&1
            sleep 15
          done
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: reporter, namespace: analytics, labels: {app: reporter}}
spec:
  replicas: 1
  selector: {matchLabels: {app: reporter}}
  template:
    metadata: {labels: {app: reporter}}
    spec:
      containers:
      - name: reporter
        image: busybox:1.36
        command: ["sh", "-c", "while true; do echo report generated at $(date); sleep 20; done"]
EOF

for ns in shop billing analytics; do
  for d in $(kubectl -n "$ns" get deploy -o name); do
    kubectl -n "$ns" rollout status "$d" --timeout=180s >/dev/null 2>&1
  done
done

echo
ok "Ambiente pronto! Leia o enunciado.md"
