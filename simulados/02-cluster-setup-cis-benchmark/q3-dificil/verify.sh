#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

M=/etc/kubernetes/manifests
D=/opt/course/02/q3

run_flag() { ps -ww -eo args | grep -E "^$1( |$)" | head -1 | tr ' ' '\n' | grep -- "^--$2=" | tail -1 | cut -d= -f2-; }
man_flag() { grep -E "^[[:space:]]*- --$2=" "$M/$1" | tail -1 | sed "s/.*--$2=//; s/[\"' ]//g"; }
perm_ok() { local p; p=$(stat -c %a "$1" 2>/dev/null) || return 1; ! (( 8#$p & 8#177 )); }

# 1. saída "antes"
F1=$D/kube-bench-node-before.txt
if [ -s "$F1" ] && grep -qE '^\[FAIL\].*anonymous-auth' "$F1"; then
  ok "kube-bench-node-before.txt contém o FAIL de anonymous-auth"
else
  fail "$F1 ausente ou sem o [FAIL] de --anonymous-auth (rodou antes de corrigir?)"
fi

if ! kubectl get --raw=/readyz >/dev/null 2>&1; then fail "kube-apiserver não responde"; finish; fi

NODE=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
systemctl is-active --quiet kubelet && ok "kubelet ativo" || fail "kubelet não está ativo"

# 2. kubelet — configuração EFETIVA via configz (inclui flags que sobrescrevem o arquivo)
CZ=$(kubectl get --raw "/api/v1/nodes/$NODE/proxy/configz" 2>/dev/null)
if [ -z "$CZ" ]; then
  fail "não foi possível ler o configz do kubelet via apiserver (apiserver -> kubelet quebrado?)"
else
  read -r ANON MODE ROP < <(echo "$CZ" | python3 -c '
import json,sys
k=json.load(sys.stdin)["kubeletconfig"]
print(str(k.get("authentication",{}).get("anonymous",{}).get("enabled")).lower(),
      k.get("authorization",{}).get("mode"), k.get("readOnlyPort",0))')
  [ "$ANON" = "false" ] && ok "kubelet em execução: anonymous auth desabilitada" || fail "kubelet em execução: anonymous.enabled=$ANON (verifique flags que sobrescrevem o config)"
  [ "$MODE" = "Webhook" ] && ok "kubelet em execução: authorization mode Webhook" || fail "kubelet em execução: authorization mode=$MODE"
  [ "$ROP" = "0" ] && ok "kubelet em execução: readOnlyPort=0" || fail "kubelet em execução: readOnlyPort=$ROP"
fi
# Comportamental
code=$(curl -sk -o /dev/null -m 5 -w '%{http_code}' https://127.0.0.1:10250/pods)
[ "$code" = "401" ] && ok "requisição anônima à API do kubelet retorna 401" || fail "requisição anônima à API do kubelet retornou HTTP $code (esperado 401)"
if curl -s -o /dev/null -m 3 http://127.0.0.1:10255/pods; then fail "porta read-only 10255 ainda responde"; else ok "porta read-only 10255 fechada"; fi
if ps -ww -eo args | grep -E '^(/usr/bin/)?kubelet ' | grep -q -- '--anonymous-auth=true'; then
  fail "processo do kubelet ainda tem --anonymous-auth=true na linha de comando"
fi
EP=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
kubectl -n kube-system logs "$EP" --tail=1 >/dev/null 2>&1 && ok "kubectl logs funciona (apiserver -> kubelet autorizado)" || fail "kubectl logs falhou (apiserver não consegue acessar o kubelet)"

# 3. permissões de arquivos
KCFG=$(run_flag /usr/bin/kubelet config); [ -z "$KCFG" ] && KCFG=$(run_flag kubelet config); KCFG=${KCFG:-/var/lib/kubelet/config.yaml}
for f in "$KCFG" /etc/kubernetes/kubelet.conf; do
  if perm_ok "$f" && [ "$(stat -c %U:%G "$f")" = "root:root" ]; then
    ok "$f com $(stat -c '%a %U:%G' "$f")"
  else
    fail "$f com $(stat -c '%a %U:%G' "$f" 2>/dev/null) (esperado 600 ou mais restritivo, root:root)"
  fi
done

# 4. etcd
mv=$(man_flag etcd.yaml client-cert-auth); rv=$(run_flag etcd client-cert-auth)
[ "$mv" = "true" ] && [ "$rv" = "true" ] && ok "etcd com --client-cert-auth=true" || fail "etcd: --client-cert-auth manifest='${mv:-ausente}' processo='${rv:-ausente}' (esperado true)"

# 5. controller-manager
mv=$(man_flag kube-controller-manager.yaml use-service-account-credentials); rv=$(run_flag kube-controller-manager use-service-account-credentials)
[ "$mv" = "true" ] && [ "$rv" = "true" ] && ok "kube-controller-manager com --use-service-account-credentials=true" \
  || fail "kube-controller-manager: --use-service-account-credentials manifest='${mv:-ausente}' processo='${rv:-ausente}'"

# saúde
st=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
[ "$st" = "True" ] && ok "node $NODE Ready" || fail "node $NODE não está Ready"
for c in kube-apiserver kube-controller-manager kube-scheduler etcd; do
  st=$(kubectl -n kube-system get pod -l component=$c -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)
  echo "$st" | grep -q true && ! echo "$st" | grep -q false && ok "$c Ready" || fail "$c não está Ready"
done

# 6. saída "depois"
F2=$D/kube-bench-node-after.txt
if [ -s "$F2" ] && grep -qE '^\[PASS\].*anonymous-auth' "$F2" && grep -qE '^\[PASS\].*authorization-mode' "$F2"; then
  ok "kube-bench-node-after.txt mostra anonymous-auth e authorization-mode em PASS"
else
  fail "$F2 ausente ou sem [PASS] para anonymous-auth/authorization-mode"
fi

finish
