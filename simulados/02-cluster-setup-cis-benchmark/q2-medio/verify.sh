#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
PKI=/etc/kubernetes/pki
D=/opt/course/02/q2

run_flag() { ps -ww -eo args | grep -E "^$1( |$)" | head -1 | tr ' ' '\n' | grep -- "^--$2=" | tail -1 | cut -d= -f2-; }
man_flag() { grep -E "^[[:space:]]*- --$2=" "$M/$1" | tail -1 | sed "s/.*--$2=//; s/[\"' ]//g"; }

if ! kubectl get --raw=/readyz >/dev/null 2>&1; then
  fail "kube-apiserver não está respondendo"; finish
fi
ok "kube-apiserver respondendo"

# 1. profiling
mv=$(man_flag kube-apiserver.yaml profiling); rv=$(run_flag kube-apiserver profiling)
[ "$mv" = "false" ] && ok "manifest: --profiling=false" || fail "manifest do apiserver sem --profiling=false (atual: '${mv:-ausente}')"
[ "$rv" = "false" ] && ok "processo: --profiling=false" || fail "apiserver em execução sem --profiling=false (atual: '${rv:-ausente}')"

# 2. authorization-mode
am=$(run_flag kube-apiserver authorization-mode)
if echo ",$am," | grep -q ',Node,' && echo ",$am," | grep -q ',RBAC,' && ! echo ",$am," | grep -q 'AlwaysAllow'; then
  ok "authorization-mode em execução: $am"
else
  fail "authorization-mode em execução incorreto: '${am:-ausente}'"
fi
# Comportamental: uma SA sem permissões não pode listar secrets
r=$(kubectl auth can-i list secrets -n kube-system --as=system:serviceaccount:default:default 2>/dev/null)
[ "$r" = "no" ] && ok "SA default:default NÃO pode listar secrets (RBAC ativo)" || fail "SA default:default consegue listar secrets ('$r') — autorização ainda permissiva"

# 3. ownership PKI
bad=$(find "$PKI" \( ! -user root -o ! -group root \) 2>/dev/null)
[ -z "$bad" ] && ok "tudo em $PKI pertence a root:root" || fail "arquivos fora de root:root em $PKI: $(echo $bad)"

# 4. permissões *.key
badk=""
while read -r k; do
  p=$(stat -c %a "$k")
  (( 8#$p & 8#177 )) && badk="$badk $k($p)"
done < <(find "$PKI" -name '*.key')
[ -z "$badk" ] && ok "todas as *.key com 600 ou mais restritivo" || fail "chaves com permissão aberta:$badk"

# 5. etcd data dir
ED=$(man_flag etcd.yaml data-dir); ED=${ED:-/var/lib/etcd}
p=$(stat -c %a "$ED" 2>/dev/null)
if [ -n "$p" ] && ! (( 8#$p & 8#077 )); then ok "$ED com permissão $p"; else fail "$ED com permissão '${p:-?}' (esperado 700 ou mais restritivo)"; fi

# saúde do control plane
for c in kube-apiserver kube-controller-manager kube-scheduler etcd; do
  st=$(kubectl -n kube-system get pod -l component=$c -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  echo "$st" | grep -q true && ! echo "$st" | grep -q false && ok "$c Ready" || fail "$c não está Ready"
done

# 6. saída do kube-bench
F=$D/kube-bench-master.txt
if [ -s "$F" ]; then
  grep -qE '^\[PASS\].*--profiling argument' "$F" && grep -qE '^\[PASS\].*--authorization-mode.*AlwaysAllow' "$F" \
    && ok "kube-bench-master.txt mostra profiling e authorization-mode em PASS" \
    || fail "kube-bench-master.txt não mostra os checks de profiling/AlwaysAllow do apiserver em [PASS] (rodou depois de corrigir?)"
  grep -qE '^\[FAIL\].*PKI (directory and file ownership|key file permissions)' "$F" \
    && fail "kube-bench-master.txt ainda mostra FAIL de PKI (ownership/permissão de chaves)" \
    || ok "kube-bench-master.txt sem FAIL de ownership/permissão de chaves PKI"
else
  fail "$F ausente"
fi

finish
