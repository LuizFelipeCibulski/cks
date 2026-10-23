#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

kubectl -n d3 get cnp crawler-egress >/dev/null 2>&1 && ok "CNP d3/crawler-egress existe" || fail "CNP d3/crawler-egress não existe"
[ -z "$(kubectl -n d3 get netpol -o name 2>/dev/null)" ] && ok "nenhuma NetworkPolicy k8s" || fail "não use NetworkPolicy nesta questão"
fq=$(kubectl -n d3 get cnp crawler-egress -o jsonpath='{.spec.egress[*].toFQDNs[*].matchName}' 2>/dev/null)
echo "$fq" | grep -qw 'kubernetes.io' && ok "toFQDNs matchName kubernetes.io" || fail "use toFQDNs com matchName: kubernetes.io"

c() { kubectl -n d3 exec crawler -- curl -s -o /dev/null -m 6 "$1" >/dev/null 2>&1; }
try() { for _ in 1 2 3; do c "$1" && return 0; sleep 2; done; return 1; }

try https://kubernetes.io && ok "crawler → https://kubernetes.io permitido" || fail "crawler deveria acessar https://kubernetes.io"
try http://cache && ok "crawler → cache:80 permitido" || fail "crawler deveria acessar http://cache"
c https://example.com && fail "crawler NÃO deveria acessar https://example.com" || ok "example.com bloqueado"
c http://kubernetes.io && fail "kubernetes.io:80 deveria estar bloqueado (só 443)" || ok "kubernetes.io:80 bloqueado"
c https://www.kubernetes.io && fail "www.kubernetes.io não deveria ser liberado (matchName exato)" || ok "www.kubernetes.io bloqueado"
finish
