#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BACKUP=/root/cks-backup/kube-apiserver.yaml

apiserver_cid() { crictl ps --name kube-apiserver -q 2>/dev/null | head -1; }

# Instala um manifest de forma atômica e espera o kubelet recriar o apiserver
apiserver_apply() {
  local src=$1 old cur
  old=$(apiserver_cid)
  cp "$src" /etc/kubernetes/.kube-apiserver.yaml.tmp
  mv /etc/kubernetes/.kube-apiserver.yaml.tmp "$MANIFEST"
  info "Aguardando o kubelet recriar o kube-apiserver..."
  for _ in $(seq 1 60); do
    cur=$(apiserver_cid)
    [ -n "$cur" ] && [ "$cur" != "$old" ] && break
    sleep 2
  done
  sleep 5
  wait_apiserver || { echo "kube-apiserver não voltou. Verifique: crictl ps -a | grep apiserver"; exit 1; }
}

# Restaura o manifest original (backup em /root/cks-backup) para partir de estado limpo
apiserver_restore() {
  if [ -f "$BACKUP" ]; then
    if ! cmp -s "$BACKUP" "$MANIFEST"; then
      info "Restaurando kube-apiserver.yaml original de $BACKUP..."
      apiserver_apply "$BACKUP"
    fi
  else
    backup_manifest kube-apiserver.yaml
  fi
  wait_apiserver || exit 1
}

apiserver_restore

info "Preparando a audit policy..."
rm -rf /var/log/kubernetes/audit /etc/kubernetes/audit
mkdir -p /etc/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # eventos do cluster geram muito ruído
  - level: None
    resources:
    - group: ""
      resources: ["events"]
  # nunca logar o conteúdo de secrets/configmaps
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets", "configmaps"]
  # alterações em qualquer outro recurso: logar o corpo da requisição
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
  # o resto não é logado
  - level: None
EOF
chmod 600 /etc/kubernetes/audit/policy.yaml
mkdir -p /var/lib/cks-sim
sha256sum /etc/kubernetes/audit/policy.yaml | awk '{print $1}' > /var/lib/cks-sim/23-q1.policy.sha256

echo
ok "Ambiente pronto! Leia o enunciado.md"
