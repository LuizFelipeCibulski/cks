#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

kubectl get --raw=/readyz >/dev/null 2>&1 && ok "kube-apiserver respondendo" || { fail "kube-apiserver fora do ar"; finish; }
grep -q -- '--encryption-provider-config=/etc/kubernetes/enc/enc.yaml' "$MANIFEST" \
  && ok "--encryption-provider-config configurado" || fail "--encryption-provider-config=/etc/kubernetes/enc/enc.yaml ausente"

E=/etc/kubernetes/enc/enc.yaml
if [ -f "$E" ]; then
  first=$(awk '/providers:/{f=1; next} f && /^ *- /{print; exit}' "$E")
  echo "$first" | grep -q aescbc && ok "aescbc é o primeiro provider" || fail "o primeiro provider deve ser aescbc (achado: $first)"
  grep -q 'identity' "$E" && ok "identity presente como fallback" || fail "identity ausente"
  grep -q 'name: *key1' "$E" && ok "chave key1" || fail "chave key1 não encontrada"
else
  fail "$E não existe"
fi

N=verify-$RANDOM
kubectl -n d7 create secret generic $N --from-literal=a=b >/dev/null
for s in db-creds api-token $N; do
  etcd_get /registry/secrets/d7/$s 2>/dev/null | grep -aq 'k8s:enc:aescbc:v1:key1' \
    && ok "d7/$s criptografada no etcd" || fail "d7/$s NÃO está criptografada com aescbc/key1"
done
kubectl -n d7 delete secret $N >/dev/null
[ "$(kubectl -n d7 get secret db-creds -o jsonpath='{.data.password}' | base64 -d)" = 'S3cr3t!' ] \
  && ok "db-creds continua legível pela API" || fail "db-creds não está legível/foi alterada"
grep -aq 'k8s:enc:aescbc:v1:key1' /opt/course/25/d7/etcd.txt 2>/dev/null && ok "etcd.txt correto" || fail "/opt/course/25/d7/etcd.txt ausente ou sem o prefixo"
finish
