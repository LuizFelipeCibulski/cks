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
NS=shop; HOST=shop.cks.local
KEY=/opt/course/ingress2/shop.key
CRT=/opt/course/ingress2/shop.crt

# 1) Arquivos de chave/certificado
if [ -s "$KEY" ] && [ -s "$CRT" ]; then
  ok "Arquivos $KEY e $CRT existem"
  BITS=$(openssl pkey -in "$KEY" -noout -text 2>/dev/null | grep -oE '[0-9]+ bit' | head -1 | cut -d' ' -f1)
  [ "$BITS" = "2048" ] && ok "Chave RSA de 2048 bits" || fail "A chave deve ser RSA 2048 bits (encontrado: ${BITS:-?})"
  [ "$(openssl pkey -in "$KEY" -pubout 2>/dev/null | sha256sum)" = "$(openssl x509 -in "$CRT" -noout -pubkey 2>/dev/null | sha256sum)" ] \
    && ok "Chave privada corresponde ao certificado" || fail "A chave $KEY não corresponde ao certificado $CRT"
  openssl x509 -in "$CRT" -noout -subject 2>/dev/null | grep -qE 'CN ?= ?shop\.cks\.local' \
    && ok "CN = $HOST" || fail "CN do certificado deve ser $HOST"
  openssl x509 -in "$CRT" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:$HOST" \
    && ok "SAN contém DNS:$HOST" || fail "O certificado não tem SAN DNS:$HOST"
  NB=$(date -d "$(openssl x509 -in "$CRT" -noout -startdate | cut -d= -f2)" +%s)
  NA=$(date -d "$(openssl x509 -in "$CRT" -noout -enddate | cut -d= -f2)" +%s)
  DAYS=$(( (NA - NB) / 86400 ))
  { [ "$DAYS" -ge 364 ] && [ "$DAYS" -le 366 ]; } && ok "Validade de $DAYS dias" || fail "Validade deve ser 365 dias (encontrado: $DAYS)"
  [ "$(openssl x509 -in "$CRT" -noout -subject | sed 's/^subject=//')" = "$(openssl x509 -in "$CRT" -noout -issuer | sed 's/^issuer=//')" ] \
    && ok "Certificado autoassinado" || fail "O certificado deveria ser autoassinado"
  FILE_FP=$(fp_of_pem < "$CRT")
else
  fail "Arquivos $KEY e/ou $CRT não encontrados"
  FILE_FP=none
fi

# 2) Secret TLS
if [ "$(kubectl -n $NS get secret shop-tls -o jsonpath='{.type}' 2>/dev/null)" = "kubernetes.io/tls" ]; then
  SEC_FP=$(kubectl -n $NS get secret shop-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | fp_of_pem)
  [ "$SEC_FP" = "$FILE_FP" ] && ok "Secret shop-tls (kubernetes.io/tls) contém $CRT" \
    || fail "Secret shop-tls não contém o certificado de $CRT"
else
  fail "Secret shop-tls do tipo kubernetes.io/tls não encontrada em $NS"
fi

# 3) Ingress com TLS
kubectl -n $NS get ingress shop -o jsonpath='{range .spec.tls[*]}{.secretName}{":"}{.hosts}{"\n"}{end}' 2>/dev/null \
  | grep -E '^shop-tls:' | grep -q "$HOST" \
  && ok "Ingress shop com tls (shop-tls / $HOST)" || fail "Ingress shop sem spec.tls com secretName shop-tls e host $HOST"

# 4) HTTPS funcionando com o certificado correto
if try_match 'backend=shop' https_get "$HOST" /; then ok "https://$HOST responde (backend=shop)"
else fail "https://$HOST não respondeu com backend=shop (saída: ${LAST:-vazia})"; fi
SERVED=$(served_cert "$HOST")
if echo "$SERVED" | openssl x509 -noout -subject 2>/dev/null | grep -qi "Fake Certificate"; then
  fail "O controller serve o 'Fake Certificate' para $HOST"
elif [ -n "$SERVED" ] && [ "$(echo "$SERVED" | fp_of_pem)" = "$FILE_FP" ]; then
  ok "Certificado servido para $HOST é o de $CRT"
else
  fail "Certificado servido para $HOST não é o esperado"
fi

# 5) Redirecionamento HTTP -> HTTPS
if try_match '^(308|301) https://shop\.cks\.local' http_code "$HOST" /cart; then
  ok "http://$HOST redireciona para HTTPS ($LAST)"
else
  fail "http://$HOST deveria redirecionar (308) para https:// (obtido: ${LAST:-nada})"
fi

finish
