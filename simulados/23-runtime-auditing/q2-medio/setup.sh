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
# Gera (a partir do manifest original) um manifest com audit logging habilitado
build_audit_manifest() {
  awk '
  {print}
  /^    - kube-apiserver$/ {
    print "    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml"
    print "    - --audit-log-path=/var/log/kubernetes/audit/audit.log"
    print "    - --audit-log-maxsize=100"
    print "    - --audit-log-maxbackup=2"
    print "    - --audit-log-maxage=7"
  }
  /^    volumeMounts:$/ {
    print "    - mountPath: /etc/kubernetes/audit"
    print "      name: audit-policy"
    print "      readOnly: true"
    print "    - mountPath: /var/log/kubernetes/audit"
    print "      name: audit-log"
    print "      readOnly: false"
  }
  /^  volumes:$/ {
    print "  - hostPath:"
    print "      path: /etc/kubernetes/audit"
    print "      type: DirectoryOrCreate"
    print "    name: audit-policy"
    print "  - hostPath:"
    print "      path: /var/log/kubernetes/audit"
    print "      type: DirectoryOrCreate"
    print "    name: audit-log"
  }' "$BACKUP" > "$1"
  grep -q -- '--audit-policy-file' "$1" && grep -q 'name: audit-log' "$1" && grep -q 'mountPath: /var/log/kubernetes/audit' "$1"
}

apiserver_restore

info "Preparando audit policy provisória..."
rm -rf /var/log/kubernetes/audit /etc/kubernetes/audit
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit
cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
# policy provisória: loga TUDO com corpo da requisição e da resposta
rules:
- level: RequestResponse
EOF

info "Habilitando audit logging no kube-apiserver..."
TMP=/root/cks-backup/kube-apiserver.23q2.yaml
build_audit_manifest "$TMP" || { echo "Falha ao preparar o manifest"; exit 1; }
apiserver_apply "$TMP"
rm -f "$TMP"

for ns in prod dev audit-test; do ns_fresh "$ns"; done

echo
ok "Ambiente pronto! Leia o enunciado.md"
