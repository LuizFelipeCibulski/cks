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

STATE=/var/lib/cks-sim/23-q3
LOG=/var/log/kubernetes/audit/audit.log

apiserver_restore

info "Limpando tentativas anteriores..."
rm -rf /var/log/kubernetes/audit /etc/kubernetes/audit /opt/course/23/q3 "$STATE"
mkdir -p /etc/kubernetes/audit /var/log/kubernetes/audit /opt/course/23/q3 "$STATE"
kubectl delete ns vault apps --ignore-not-found --wait=true >/dev/null 2>&1

cat > /etc/kubernetes/audit/policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
EOF

info "Habilitando audit logging no kube-apiserver..."
TMP=/root/cks-backup/kube-apiserver.23q3.yaml
build_audit_manifest "$TMP" || { echo "Falha ao preparar o manifest"; exit 1; }
apiserver_apply "$TMP"
rm -f "$TMP"

info "Criando cenário (namespaces vault e apps)..."
kubectl create ns vault >/dev/null
kubectl create ns apps >/dev/null
kubectl -n vault create secret generic db-credentials --from-literal=username=app --from-literal=password='Sup3r-S3cret' >/dev/null
kubectl -n vault create secret generic api-key --from-literal=key='0f8c2d1e9a' >/dev/null
kubectl -n vault create sa backup-agent >/dev/null
kubectl -n vault create sa monitoring >/dev/null
kubectl -n apps create sa ci-runner >/dev/null
kubectl -n apps create sa deployer >/dev/null

cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: secret-reader, namespace: vault}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["db-credentials"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: secret-manager, namespace: vault}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "patch", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: {name: pod-viewer, namespace: vault}
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: backup, namespace: vault}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: secret-reader}
subjects:
- {kind: ServiceAccount, name: backup-agent, namespace: vault}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: vault-maintenance, namespace: vault}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: secret-manager}
subjects:
- {kind: ServiceAccount, name: ci-runner, namespace: apps}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: observability, namespace: vault}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: Role, name: pod-viewer}
subjects:
- {kind: ServiceAccount, name: monitoring, namespace: vault}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: {name: deployer, namespace: apps}
roleRef: {apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: edit}
subjects:
- {kind: ServiceAccount, name: deployer, namespace: apps}
EOF
sleep 3

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=/etc/kubernetes/pki/ca.crt
T_BACKUP=$(kubectl -n vault create token backup-agent)
T_MON=$(kubectl -n vault create token monitoring)
T_CI=$(kubectl -n apps create token ci-runner)
T_DEP=$(kubectl -n apps create token deployer)
api() { # token método caminho [corpo]
  local t=$1 m=$2 p=$3 b=$4
  if [ -n "$b" ]; then
    curl -s -o /dev/null --cacert $CA -H "Authorization: Bearer $t" -X "$m" \
      -H 'Content-Type: application/merge-patch+json' -A 'kubectl/v1.34.0 (linux/amd64) kubernetes/unknown' \
      --data "$b" "$SERVER$p"
  else
    curl -s -o /dev/null --cacert $CA -H "Authorization: Bearer $t" -X "$m" \
      -A 'kubectl/v1.34.0 (linux/amd64) kubernetes/unknown' "$SERVER$p"
  fi
}

info "Gerando atividade no cluster..."
api "$T_BACKUP" GET /api/v1/namespaces/vault/secrets/db-credentials;          sleep 2
api "$T_MON"    GET /api/v1/namespaces/vault/pods;                            sleep 1
api "$T_MON"    GET /api/v1/namespaces/vault/secrets/db-credentials;          sleep 2   # 403
api "$T_DEP"    GET /api/v1/namespaces/apps/configmaps;                       sleep 1
api "$T_CI"     GET /api/v1/namespaces/vault/secrets;                         sleep 2
api "$T_CI"     GET /api/v1/namespaces/vault/secrets/db-credentials;          sleep 3
NEWPW=$(printf 'pwn3d-by-ci' | base64)
api "$T_CI"     PATCH /api/v1/namespaces/vault/secrets/db-credentials "{\"data\":{\"password\":\"$NEWPW\"}}"; sleep 2
api "$T_CI"     GET /api/v1/namespaces/vault/secrets/api-key;                 sleep 2
kubectl -n vault patch secret api-key -p "{\"data\":{\"key\":\"$(printf 'rotated-7b1e' | base64)\"}}" >/dev/null; sleep 2
api "$T_BACKUP" GET /api/v1/namespaces/vault/secrets/db-credentials;          sleep 1
api "$T_DEP"    PATCH /api/v1/namespaces/apps/serviceaccounts/deployer '{"metadata":{"labels":{"team":"ci"}}}'
sleep 3

# gabarito
python3 - "$LOG" "$STATE/time" <<'PYEOF'
import json, sys
ts = None
for l in open(sys.argv[1], errors="replace"):
    if "db-credentials" not in l or '"patch"' not in l:
        continue
    try:
        e = json.loads(l)
    except Exception:
        continue
    o = e.get("objectRef") or {}
    if o.get("resource") == "secrets" and o.get("name") == "db-credentials" and e.get("verb") == "patch" \
       and e.get("user", {}).get("username") == "system:serviceaccount:apps:ci-runner":
        ts = e.get("requestReceivedTimestamp")
if ts:
    open(sys.argv[2], "w").write(ts + "\n")
PYEOF
[ -s "$STATE/time" ] || { echo "Não foi possível gerar o cenário no audit log. Rode o setup novamente."; exit 1; }

echo
ok "Ambiente pronto! Leia o enunciado.md"
