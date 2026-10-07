#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

ENC=/etc/kubernetes/etcd/ec.yaml
etcd_get() {
  if command -v etcdctl >/dev/null; then
    ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/apiserver-etcd-client.crt --key=/etc/kubernetes/pki/apiserver-etcd-client.key \
      get "$1" --print-value-only 2>/dev/null
  else
    local p; p=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    kubectl -n kube-system exec "$p" -- etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
      --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
      get "$1" --print-value-only 2>/dev/null
  fi
}
enc_prefix() { etcd_get "$1" | head -c 40 | grep -aoE 'k8s:enc:(aescbc|secretbox):v1:[^:]*'; }

kubectl get --raw=/readyz >/dev/null 2>&1 && ok "kube-apiserver respondendo" || { fail "kube-apiserver não responde"; finish; }

flag=$(ps -eo args | grep '[k]ube-apiserver ' | grep -oE -- '--encryption-provider-config=[^ ]+' | cut -d= -f2)
[ "$flag" = "$ENC" ] && ok "kube-apiserver usa --encryption-provider-config=$ENC" || fail "flag --encryption-provider-config=$ENC ausente (atual: '$flag')"

if [ -f $ENC ]; then
  first=$(awk '/providers:/{f=1;next} f && /^[[:space:]]*-[[:space:]]*[a-z]+:/{gsub(/[[:space:]-]/,""); sub(/:.*/,""); print; exit}' $ENC)
  case "$first" in aescbc|secretbox) ok "primeiro provider é $first (usado para gravar)";; *) fail "o primeiro provider deve ser aescbc ou secretbox (atual: '$first') — o primeiro da lista é o que cifra";; esac
  grep -qE '^[[:space:]]*-[[:space:]]*identity:' $ENC && ok "identity mantido como fallback de leitura" || fail "identity: {} deveria continuar na lista (depois do provider de cifra)"
  key=$(grep -m1 -E '^[[:space:]]*secret:' $ENC | sed -E 's/^[[:space:]]*secret:[[:space:]]*//; s/["'\'']//g; s/[[:space:]]*#.*$//')
  len=$(echo -n "$key" | base64 -d 2>/dev/null | wc -c)
  [ "$len" = "32" ] && ok "chave tem 32 bytes" || fail "a chave deve ter 32 bytes depois de decodificada (tem $len)"
  [ "$key" != "bWluaGEtY2hhdmU=" ] && ok "chave do rascunho foi substituída" || fail "chave do rascunho ainda em uso"
else
  fail "$ENC não existe"
fi

for s in bank/bank-creds bank/bank-api-key default/cks-legacy-token; do
  p=$(enc_prefix "/registry/secrets/$s")
  [ -n "$p" ] && ok "Secret $s cifrado no etcd ($p)" || fail "Secret $s NÃO está cifrado no etcd"
done

total=0; plain=""
while read -r ns n; do
  total=$((total+1))
  [ -z "$(enc_prefix "/registry/secrets/$ns/$n")" ] && plain="$plain $ns/$n"
done < <(kubectl get secrets -A --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name)
[ -z "$plain" ] && ok "Todos os $total Secrets do cluster estão cifrados" || fail "Secrets ainda em texto puro no etcd:$plain"

kubectl -n bank create secret generic verify-probe --from-literal=a=b >/dev/null 2>&1
[ -n "$(enc_prefix /registry/secrets/bank/verify-probe)" ] && ok "Novos Secrets são cifrados" || fail "Novo Secret não foi cifrado"
kubectl -n bank delete secret verify-probe >/dev/null 2>&1

[ "$(kubectl -n bank get secret bank-creds -o jsonpath='{.data.pass}' | base64 -d)" = 'C0fr3-F0rt3!' ] && ok "bank-creds legível via API com o valor original" || fail "bank-creds não está legível/correto via API"

f=/opt/course/15/q3/etcd-bank-creds.txt
[ -s $f ] && grep -aqE 'k8s:enc:(aescbc|secretbox):v1:' $f && ok "$f mostra o dado cifrado" || fail "$f ausente ou não mostra o prefixo k8s:enc:<provider>:v1:"

ls /etc/kubernetes/manifests | grep apiserver | grep -vx 'kube-apiserver.yaml' | grep -q . \
  && fail "Há cópias do apiserver em /etc/kubernetes/manifests (backups ali viram static pods!)" || ok "/etc/kubernetes/manifests limpo"

finish
