#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

[ "$(kubectl get runtimeclass gvisor -o jsonpath='{.handler}' 2>/dev/null)" = "runsc" ] && ok "RuntimeClass gvisor com handler runsc" || fail "RuntimeClass gvisor (handler runsc) não existe"

jp() { kubectl -n sandbox get pod sandboxed -o jsonpath="$1" 2>/dev/null; }
[ "$(jp '{.spec.runtimeClassName}')" = "gvisor" ] && ok "Pod sandboxed usa runtimeClassName gvisor" || fail "Pod sandboxed não usa runtimeClassName: gvisor"
[ "$(jp '{.spec.containers[0].image}')" = "nginx:1.27-alpine" ] && ok "imagem nginx:1.27-alpine" || fail "imagem deve ser nginx:1.27-alpine"
[ "$(jp '{.status.phase}')" = "Running" ] && ok "Pod Running" || fail "Pod sandboxed não está Running (veja: kubectl -n sandbox describe pod sandboxed)"

kubectl -n sandbox exec sandboxed -- dmesg 2>/dev/null | grep -qi gvisor && ok "dmesg dentro do Pod mostra o kernel do gVisor" || fail "o Pod não está rodando no gVisor (dmesg não mostra gVisor)"

finish
