#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

MANIFEST=/etc/kubernetes/manifests/kube-apiserver.yaml
DIR=/etc/kubernetes/policywebhook

# flags do processo em execução (fonte da verdade, não só o manifest)
flag() { ps -eo args | grep -E '^(/usr/local/bin/)?kube-apiserver ' | head -1 | tr ' ' '\n' | grep -- "^--$1=" | head -1 | cut -d= -f2-; }

# 0 - apiserver no ar
if kubectl get --raw=/readyz >/dev/null 2>&1; then ok "kube-apiserver respondendo"
else fail "kube-apiserver não está respondendo (veja crictl ps -a / logs em /var/log/pods/kube-system_kube-apiserver*)"; finish; fi

# 1/2/3 - admission_config.json
CONF=$(flag admission-control-config-file)
[ -z "$CONF" ] && CONF=$DIR/admission_config.json
if [ -f "$CONF" ]; then
  if grep -Eq '"?kubeConfigFile"?[[:space:]]*:[[:space:]]*"?/etc/kubernetes/policywebhook/kubeconf"?[[:space:]]*,?[[:space:]]*$' "$CONF"; then
    ok "admission config aponta para /etc/kubernetes/policywebhook/kubeconf"
  else
    fail "kubeConfigFile em $CONF não aponta para /etc/kubernetes/policywebhook/kubeconf"
  fi
  grep -Eq '"?allowTTL"?[[:space:]]*:[[:space:]]*100([^0-9]|$)' "$CONF" && ok "allowTTL = 100" || fail "allowTTL não é 100"
  grep -Eq '"?defaultAllow"?[[:space:]]*:[[:space:]]*false' "$CONF" && ok "defaultAllow = false (fail closed)" || fail "defaultAllow deveria ser false"
else
  fail "arquivo de admission config $CONF não existe no host"
fi

# 4 - kubeconf
if grep -Eq '^[[:space:]]*server:[[:space:]]*"?https://localhost:1234/?"?([[:space:]]|#|$)' $DIR/kubeconf; then
  ok "kubeconf aponta para https://localhost:1234"
else
  fail "kubeconf não aponta para https://localhost:1234"
fi

# 5 - flags do apiserver
plugins=$(flag enable-admission-plugins)
[[ ",$plugins," == *",ImagePolicyWebhook,"* ]] && ok "ImagePolicyWebhook habilitado no processo kube-apiserver" || fail "ImagePolicyWebhook não está em --enable-admission-plugins ($plugins)"
[[ ",$plugins," == *",NodeRestriction,"* ]] && ok "NodeRestriction continua habilitado" || fail "NodeRestriction foi removido de --enable-admission-plugins"
if [ -n "$(flag admission-control-config-file)" ]; then
  ok "--admission-control-config-file=$(flag admission-control-config-file)"
else
  fail "--admission-control-config-file não configurado no kube-apiserver"
fi

# volume montado: algum mountPath deve conter o arquivo de configuração
mounted=0
for mp in $(grep -E 'mountPath:' "$MANIFEST" | awk '{print $NF}' | tr -d "\"'"); do
  mp=${mp%/}
  [[ "$CONF" == "$mp"/* ]] && mounted=1
done
[ $mounted -eq 1 ] && ok "diretório da configuração está montado no container do apiserver" || fail "nenhum volumeMount do apiserver contém $CONF"

# 6 - comportamento: criação de Pod deve ser negada
kubectl delete pod ipw-test -n default --ignore-not-found --wait=false >/dev/null 2>&1
out=$(kubectl run ipw-test -n default --image=registry.k8s.io/pause:3.10 2>&1)
if [ $? -eq 0 ]; then
  fail "Pod foi criado — o ImagePolicyWebhook não está bloqueando (fail closed)"
  kubectl delete pod ipw-test -n default --wait=false >/dev/null 2>&1
else
  ok "criação de Pod negada: $(echo "$out" | head -1 | cut -c1-160)"
fi

echo
echo "Lembrete: depois de terminar, restaure o apiserver original para voltar a criar Pods:"
echo "  cp /root/cks-backup/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml"
finish
