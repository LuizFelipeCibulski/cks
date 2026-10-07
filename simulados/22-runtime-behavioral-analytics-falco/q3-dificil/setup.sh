#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

if grep -q ImagePolicyWebhook /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null; then
  echo "O kube-apiserver está com ImagePolicyWebhook ativo (questão 21-Q3) e nenhum Pod pode ser criado."
  echo "Restaure antes: cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
  exit 1
fi

STATE=/var/lib/cks-sim/22-q3
LOCAL=/etc/falco/falco_rules.local.yaml

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

install_falco
command -v falco >/dev/null || { echo "Falha ao instalar o Falco"; exit 1; }
SVC=$(falco_svc)
mkdir -p /root/cks-backup
if [ ! -f /root/cks-backup/falco_rules.local.yaml ]; then
  if [ -f "$LOCAL" ]; then cp -a "$LOCAL" /root/cks-backup/falco_rules.local.yaml
  else printf '# Your custom rules!\n' > /root/cks-backup/falco_rules.local.yaml; fi
fi

info "Limpando tentativas anteriores..."
rm -rf /opt/course/22/q3 "$STATE"
mkdir -p /opt/course/22/q3 "$STATE"
ns_fresh finance
ns_fresh ops

info "Criando workloads..."
cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: ledger-api
  namespace: finance
  labels: {app: ledger-api}
spec:
  containers:
  - name: api
    image: httpd:2.4-alpine
---
apiVersion: v1
kind: Pod
metadata:
  name: ledger-worker
  namespace: finance
  labels: {app: ledger-worker}
spec:
  containers:
  - name: worker
    image: busybox:1.36
    command:
    - sh
    - -c
    - >-
      mkdir -p /tmp/.cache && cp /bin/busybox /tmp/.cache/busybox &&
      exec /tmp/.cache/busybox sh -c 'i=0; while true; do i=$((i+1));
      echo "svc$i:x:0:0::/root:/bin/sh" >> /etc/passwd; sleep 5; done'
---
apiVersion: v1
kind: Pod
metadata:
  name: backup
  namespace: ops
  labels: {app: backup}
spec:
  containers:
  - name: backup
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /tmp/backup.log; sleep 5; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: config-reader
  namespace: ops
  labels: {app: config-reader}
spec:
  containers:
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "while true; do cat /etc/hostname /etc/resolv.conf > /dev/null; sleep 5; done"]
EOF

wait_pods finance
wait_pods ops
cid=$(kubectl -n finance get pod ledger-worker -o jsonpath='{.status.containerStatuses[0].containerID}')
cid=${cid#*://}
[ -n "$cid" ] || { echo "Pod finance/ledger-worker não iniciou. Rode o setup novamente."; exit 1; }
echo "${cid:0:12}" > "$STATE/cid"

info "Aplicando a regra 'quebrada' do colega e reiniciando o Falco..."
cat > "$LOCAL" <<'EOF'
# Your custom rules!

- rule: Write below etc in container
  desc: Detecta escrita em arquivos abaixo de /etc dentro de containers
  condition: open_write and container and fd.nam startswith /etc
  output: "File below /etc opened for writing (user=%user.name command=%proc.cmdline file=%fd.name)"
  priority: NOTICE
  tags: [filesystem, container, cks]
EOF
systemctl restart "$SVC" >/dev/null 2>&1
sleep 5

echo
ok "Ambiente pronto! Leia o enunciado.md"
