#!/usr/bin/env bash
# Desfaz tudo da revisão final: apiserver original, Falco original, namespaces e CCNP.
D=$(dirname "$(readlink -f "$0")"); source "$D/_lib.sh"
require_root; require_controlplane
apiserver_reset
command -v falco >/dev/null && falco_reset
kubectl delete ccnp debug-deny-world --ignore-not-found >/dev/null 2>&1
for ns in d1 store legacy d3 d4 d4-other d5 d6 d7; do kubectl delete ns "$ns" --ignore-not-found --wait=false >/dev/null; done
rm -rf /opt/course/25
ok "Reset concluído"
