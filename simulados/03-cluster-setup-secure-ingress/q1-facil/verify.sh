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
NS=secure-web; HOST=web.cks.local
CRT=/opt/course/ingress1/tls.crt
FILE_FP=$(fp_of_pem < "$CRT")

# 1) Secret TLS
if [ "$(kubectl -n $NS get secret web-tls -o jsonpath='{.type}' 2>/dev/null)" = "kubernetes.io/tls" ]; then
  ok "Secret web-tls do tipo kubernetes.io/tls existe em $NS"
  SEC_FP=$(kubectl -n $NS get secret web-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | fp_of_pem)
  [ -n "$SEC_FP" ] && [ "$SEC_FP" = "$FILE_FP" ] && ok "Secret contém o certificado de $CRT" \
    || fail "O certificado da secret web-tls não é o de $CRT"
else
  fail "Secret web-tls (tipo kubernetes.io/tls) não encontrada no namespace $NS"
fi

# 2) Ingress com TLS
TLS=$(kubectl -n $NS get ingress web -o jsonpath='{range .spec.tls[*]}{.secretName}{":"}{.hosts}{"\n"}{end}' 2>/dev/null)
echo "$TLS" | grep -E '^web-tls:' | grep -q "$HOST" \
  && ok "Ingress web tem bloco tls com secretName web-tls e host $HOST" \
  || fail "Ingress web não tem spec.tls com secretName web-tls e hosts [$HOST]"

RULE_HOST=$(kubectl -n $NS get ingress web -o jsonpath='{.spec.rules[0].host}' 2>/dev/null)
[ "$RULE_HOST" = "$HOST" ] && ok "Regra do host $HOST mantida" || fail "A regra do host $HOST foi alterada/removida"

# 3) Comportamento: HTTPS responde e serve o certificado correto
if try_match 'backend=web' https_get "$HOST" /; then
  ok "https://$HOST responde via ingress (backend=web)"
else
  fail "https://$HOST não respondeu com o backend web (saída: ${LAST:-vazia})"
fi
SERVED=$(served_cert "$HOST")
if echo "$SERVED" | openssl x509 -noout -subject 2>/dev/null | grep -qi "Fake Certificate"; then
  fail "O controller ainda serve o 'Kubernetes Ingress Controller Fake Certificate' para $HOST"
elif [ -n "$SERVED" ] && [ "$(echo "$SERVED" | fp_of_pem)" = "$FILE_FP" ]; then
  ok "Certificado servido para $HOST é o de $CRT"
else
  fail "Certificado servido para $HOST não é o esperado"
fi

finish
