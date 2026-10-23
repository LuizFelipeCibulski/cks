#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root

g=$(kubectl -n d4 get cnp legacy-allow-all -o jsonpath='{.metadata.generation} {.spec.ingress[0].fromEntities[0]}' 2>/dev/null)
[ "$g" = "1 all" ] && ok "legacy-allow-all intacta" || fail "legacy-allow-all foi apagada ou editada ($g)"
[ -n "$(kubectl -n d4 get cnp db-deny -o jsonpath='{.spec.ingressDeny}' 2>/dev/null)" ] \
  && ok "db-deny usa ingressDeny" || fail "CNP d4/db-deny inexistente ou sem ingressDeny"
[ -n "$(kubectl get ccnp debug-deny-world -o jsonpath='{.spec.egressDeny}' 2>/dev/null)" ] \
  && ok "CCNP debug-deny-world usa egressDeny" || fail "CCNP debug-deny-world inexistente ou sem egressDeny"

c() { kubectl -n "$1" exec "$2" -- curl -s -o /dev/null -m 5 "$3" >/dev/null 2>&1; }
allow() { for _ in 1 2 3; do c "$@" && { ok "$1/$2 → $3 permitido"; return; }; sleep 2; done; fail "$1/$2 → $3 deveria funcionar"; }
deny()  { c "$@" && fail "$1/$2 → $3 deveria ser BLOQUEADO" || ok "$1/$2 → $3 bloqueado"; }

allow d4 app http://db
deny  d4 debug http://db
deny  d4-other client http://db.d4
deny  d4-other scanner http://db.d4
allow d4 debug http://echo.d4-other
allow d4-other scanner http://echo
deny  d4 debug https://example.com
deny  d4-other scanner https://example.com
allow d4 app https://example.com
allow d4-other client https://example.com
finish
