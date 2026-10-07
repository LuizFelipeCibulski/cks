#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
BACKUP=/root/cks-backup/kube-apiserver.yaml
DIR=/etc/kubernetes/policywebhook

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

# 1) parte de um estado limpo
apiserver_restore

# 2) diretório de configuração "meio pronto"
info "Criando $DIR (configuração incompleta)..."
rm -rf "$DIR"
mkdir -p "$DIR"
cd "$DIR" || exit 1

# certificados (CA do serviço externo e certificado de cliente do apiserver)
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -keyout external-key.pem -out external-cert.pem >/dev/null 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=kube-apiserver-imagepolicy" \
  -keyout apiserver-client-key.pem -out apiserver-client-cert.pem >/dev/null 2>&1
chmod 600 ./*key.pem

cat > admission_config.json <<'EOF'
{
   "apiVersion": "apiserver.config.k8s.io/v1",
   "kind": "AdmissionConfiguration",
   "plugins": [
      {
         "name": "ImagePolicyWebhook",
         "configuration": {
            "imagePolicy": {
               "kubeConfigFile": "/etc/kubernetes/policywebhook/kubeconfig.yaml",
               "allowTTL": 50,
               "denyTTL": 50,
               "retryBackoff": 500,
               "defaultAllow": true
            }
         }
      }
   ]
}
EOF

cat > kubeconf <<'EOF'
apiVersion: v1
kind: Config

# clusters refers to the remote service.
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/policywebhook/external-cert.pem  # CA for verifying the remote service.
    server: https://image-checker.example.com:8443                          # URL of remote service to query. Must use 'https'.
  name: image-checker

contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
preferences: {}

# users refers to the API server's webhook configuration.
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/policywebhook/apiserver-client-cert.pem     # cert for the webhook admission controller to use
    client-key:  /etc/kubernetes/policywebhook/apiserver-client-key.pem             # key matching the cert
EOF

# 3) manifest "meio pronto": o colega declarou o volume, mas não montou nem configurou as flags
info "Aplicando alterações parciais no kube-apiserver..."
TMP=/root/cks-backup/kube-apiserver.21q3.yaml
awk '
{print}
/^  volumes:$/ {
  print "  - hostPath:"
  print "      path: /etc/kubernetes/policywebhook"
  print "      type: DirectoryOrCreate"
  print "    name: policywebhook"
}' "$BACKUP" > "$TMP"
grep -q 'name: policywebhook' "$TMP" || { echo "Falha ao preparar o manifest"; exit 1; }
apiserver_apply "$TMP"
rm -f "$TMP"

kubectl delete pod ipw-test -n default --ignore-not-found >/dev/null 2>&1

echo
ok "Ambiente pronto! Leia o enunciado.md"
