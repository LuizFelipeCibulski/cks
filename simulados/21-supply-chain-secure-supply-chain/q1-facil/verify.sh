#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=supply-chain
STATE=/var/lib/cks-sim/21-q1
[ -f "$STATE/api.digest" ] || { echo "Estado do setup não encontrado. Rode: bash setup.sh"; exit 1; }

check_container() {
  local c=$1 repo=$2
  local img; img=$(kubectl -n "$NS" get deploy payment-api -o jsonpath="{.spec.template.spec.containers[?(@.name=='$c')].image}" 2>/dev/null)
  local want; want=$(cat "$STATE/$c.digest")
  if [ -z "$img" ]; then fail "container '$c' não encontrado no Deployment"; return; fi
  if [[ ! "$img" =~ @sha256:[0-9a-f]{64}$ ]]; then
    fail "container '$c' não usa digest (image=$img)"; return
  fi
  local ref=${img%@*}            # parte antes do @
  local last=${ref##*/}          # último segmento do repositório
  if [[ "$last" == *:* ]]; then
    fail "container '$c' ainda tem tag junto com o digest ($img) — remova a tag"
  else
    ok "container '$c' referencia imagem por digest sem tag"
  fi
  if [[ "$last" != "$repo" ]]; then
    fail "container '$c' mudou de repositório ($ref) — deveria continuar sendo $repo"
  fi
  if [ "${img##*@}" == "$want" ]; then
    ok "digest de '$c' é o mesmo que estava em execução"
  else
    fail "digest de '$c' (${img##*@}) difere do digest que estava rodando ($want)"
  fi
}

check_container api nginx
check_container log-agent busybox

if kubectl -n "$NS" rollout status deploy/payment-api --timeout=60s >/dev/null 2>&1; then
  ok "rollout do Deployment concluído"
else
  fail "rollout do Deployment não concluiu"
fi

ready=$(kubectl -n "$NS" get deploy payment-api -o jsonpath='{.status.readyReplicas}')
want=$(kubectl -n "$NS" get deploy payment-api -o jsonpath='{.spec.replicas}')
if [ -n "$ready" ] && [ "$ready" == "$want" ]; then
  ok "todas as réplicas prontas ($ready/$want)"
else
  fail "réplicas prontas: ${ready:-0}/$want"
fi

# Pods em execução devem usar a nova especificação
bad=0
for p in $(kubectl -n "$NS" get pod -l app=payment-api -o go-template='{{range .items}}{{if not .metadata.deletionTimestamp}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}'); do
  imgs=$(kubectl -n "$NS" get pod "$p" -o jsonpath='{.spec.containers[*].image}')
  for i in $imgs; do [[ "$i" == *@sha256:* ]] || bad=1; done
done
[ $bad -eq 0 ] && ok "Pods em execução usam imagens por digest" || fail "ainda há Pods rodando com imagens por tag"

finish
