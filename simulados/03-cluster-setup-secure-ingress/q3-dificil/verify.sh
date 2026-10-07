#!/usr/bin/env bash
# Secure Ingress — VERIFY
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# ---------------------------------------------------------------------------
# Helpers locais de verificação (repetidos em cada verify desta pasta)
# ---------------------------------------------------------------------------
discover_ingress() {
  local line
  line=$(kubectl get svc -A -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller \
          --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name 2>/dev/null | grep -v admission | head -1)
  ING_NS=$(echo "$line" | awk '{print $1}'); ING_SVC=$(echo "$line" | awk '{print $2}')
  if [ -z "$ING_SVC" ]; then fail "ingress-nginx controller não encontrado (rode o setup.sh)"; finish; fi
  HTTP_PORT=$(kubectl -n "$ING_NS" get svc "$ING_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
  HTTPS_PORT=$(kubectl -n "$ING_NS" get svc "$ING_SVC" -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
  NODE_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
}

# GET via HTTPS usando --resolve (SNI + Host corretos)
https_get() { curl -sk --max-time 5 --resolve "$1:$HTTPS_PORT:$NODE_IP" "https://$1:$HTTPS_PORT$2"; }
# Status + Location via HTTP
http_code() { curl -s -o /dev/null --max-time 5 -w '%{http_code} %{redirect_url}' --resolve "$1:$HTTP_PORT:$NODE_IP" "http://$1:$HTTP_PORT$2"; }
# Certificado servido pelo controller para um SNI
served_cert() { echo | timeout 5 openssl s_client -connect "$NODE_IP:$HTTPS_PORT" -servername "$1" 2>/dev/null | openssl x509 2>/dev/null; }
fp_of_pem() { openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2; }

# Repete um comando até a saída casar com a regex (o controller leva alguns segundos para recarregar)
try_match() {
  local exp=$1; shift; local out=""
  for _ in 1 2 3 4 5 6; do
    out=$("$@" 2>/dev/null)
    if echo "$out" | grep -qE "$exp"; then LAST="$out"; return 0; fi
    sleep 2
  done
  LAST="$out"; return 1
}
# ---------------------------------------------------------------------------

discover_ingress
NS=portal
KEY=/opt/course/ingress3/portal.key
CRT=/opt/course/ingress3/portal.crt
HOSTS="portal.cks.local admin.cks.local"

# 1) Novo par chave/certificado
FILE_FP=none
if [ -s "$KEY" ] && [ -s "$CRT" ]; then
  ok "Arquivos $KEY e $CRT existem"
  [ "$(openssl pkey -in "$KEY" -pubout 2>/dev/null | sha256sum)" = "$(openssl x509 -in "$CRT" -noout -pubkey 2>/dev/null | sha256sum)" ] \
    && ok "Chave corresponde ao certificado" || fail "A chave $KEY não corresponde a $CRT"
  openssl x509 -in "$CRT" -noout -subject 2>/dev/null | grep -qE 'CN ?= ?portal\.cks\.local' \
    && ok "CN = portal.cks.local" || fail "CN do certificado deve ser portal.cks.local"
  for h in $HOSTS; do
    openssl x509 -in "$CRT" -noout -checkhost "$h" 2>/dev/null | grep -q 'does match' \
      && ok "Certificado válido (SAN) para $h" || fail "SAN do certificado não cobre $h"
  done
  FILE_FP=$(fp_of_pem < "$CRT")
else
  fail "Arquivos $KEY e/ou $CRT não encontrados"
fi

# 2) Secret no namespace correto
if [ "$(kubectl -n $NS get secret portal-tls -o jsonpath='{.type}' 2>/dev/null)" = "kubernetes.io/tls" ]; then
  SEC_FP=$(kubectl -n $NS get secret portal-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | fp_of_pem)
  [ "$SEC_FP" = "$FILE_FP" ] && ok "Secret portal-tls em $NS contém $CRT" || fail "Secret portal-tls em $NS não contém o certificado de $CRT"
else
  fail "Secret portal-tls (kubernetes.io/tls) não existe no namespace $NS"
fi

# 3) Não criar Services novos / não alterar os existentes
kubectl -n $NS get svc admin-svc >/dev/null 2>&1 && fail "Não era para criar o Service admin-svc — corrija o Ingress" || ok "Nenhum Service extra criado"
[ "$(kubectl -n $NS get svc api -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)" = "80" ] \
  && ok "Service api mantido na porta 80" || fail "O Service api foi alterado (porta deveria continuar 80)"

# 4) TLS no ingress cobrindo os dois hosts
TLSH=$(kubectl -n $NS get ingress portal -o jsonpath='{range .spec.tls[*]}{.secretName}{":"}{.hosts}{"\n"}{end}' 2>/dev/null)
for h in $HOSTS; do
  echo "$TLSH" | grep "\"$h\"" | grep -q '^portal-tls:' && ok "spec.tls do Ingress inclui $h (portal-tls)" \
    || fail "spec.tls do Ingress portal não inclui $h com secretName portal-tls"
done

# 5) Roteamento via HTTPS
check_route() { # host path esperado
  if try_match "backend=$3\$" https_get "$1" "$2"; then ok "https://$1$2 -> $3"
  else fail "https://$1$2 deveria ir para '$3' (obtido: $(echo "${LAST:-vazio}" | head -1 | cut -c1-60))"; fi
}
check_route portal.cks.local / web
check_route portal.cks.local /index.html web
check_route portal.cks.local /api api
check_route portal.cks.local /api/v1/health api
check_route admin.cks.local / admin
check_route admin.cks.local /users admin

# 6) Certificado servido para cada host
for h in $HOSTS; do
  SERVED=$(served_cert "$h")
  if echo "$SERVED" | openssl x509 -noout -subject 2>/dev/null | grep -qi "Fake Certificate"; then
    fail "Controller serve o 'Fake Certificate' para $h"
  elif [ -n "$SERVED" ] && [ "$(echo "$SERVED" | fp_of_pem)" = "$FILE_FP" ]; then
    ok "Certificado correto servido para $h"
  else
    fail "Certificado servido para $h não é o de $CRT"
  fi
done

# 7) Redirecionamento HTTP -> HTTPS
for h in $HOSTS; do
  if try_match "^(308|301) https://$h" http_code "$h" /; then ok "http://$h redireciona para HTTPS"
  else fail "http://$h deveria redirecionar para https:// (obtido: ${LAST:-nada})"; fi
done

# 8) NodePort HTTPS
ANS=$(tr -d '[:space:]' < /opt/course/ingress3/https-nodeport 2>/dev/null)
[ -n "$ANS" ] && [ "$ANS" = "$HTTPS_PORT" ] && ok "NodePort HTTPS correto em /opt/course/ingress3/https-nodeport" \
  || fail "/opt/course/ingress3/https-nodeport deveria conter o NodePort HTTPS do ingress controller"

finish
