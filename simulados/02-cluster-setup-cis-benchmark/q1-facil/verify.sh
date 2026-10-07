#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
D=/opt/course/02/q1

# valor da última ocorrência de --<flag>= no processo em execução
run_flag() { ps -ww -eo args | grep -E "^$1( |$)" | head -1 | tr ' ' '\n' | grep -- "^--$2=" | tail -1 | cut -d= -f2-; }
man_flag() { grep -E "^[[:space:]]*- --$2=" "$M/$1" | tail -1 | sed "s/.*--$2=//; s/[\"' ]//g"; }

# 1. saída "antes"
if [ -s "$D/kube-bench-before.txt" ] && grep -qE '^\[FAIL\].*--profiling' "$D/kube-bench-before.txt"; then
  ok "kube-bench-before.txt existe e contém os FAIL de profiling"
else
  fail "$D/kube-bench-before.txt ausente ou sem os [FAIL] de --profiling (rodou o kube-bench antes de corrigir?)"
fi

# 2/3. flags
for c in kube-controller-manager kube-scheduler; do
  mv=$(man_flag "$c.yaml" profiling)
  rv=$(run_flag "$c" profiling)
  if [ "$mv" = "false" ]; then ok "$c: manifest com --profiling=false"; else fail "$c: manifest não tem --profiling=false (atual: '${mv:-ausente}')"; fi
  if [ "$rv" = "false" ]; then ok "$c: processo em execução com --profiling=false"; else fail "$c: processo em execução não está com --profiling=false (atual: '${rv:-ausente}')"; fi
done

# 4. pods saudáveis
for c in kube-controller-manager kube-scheduler; do
  st=$(kubectl -n kube-system get pod -l component=$c -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  if echo "$st" | grep -q true && ! echo "$st" | grep -q false; then ok "$c Running/Ready"; else fail "$c não está Ready"; fi
done

# 5. saída "depois"
if [ -s "$D/kube-bench-after.txt" ]; then
  n=$(grep -cE '^\[PASS\].*--profiling' "$D/kube-bench-after.txt")
  if [ "$n" -ge 2 ]; then ok "kube-bench-after.txt mostra os checks de profiling em PASS ($n)"; else fail "kube-bench-after.txt não mostra ao menos 2 checks de --profiling em [PASS]"; fi
else
  fail "$D/kube-bench-after.txt ausente"
fi

finish
