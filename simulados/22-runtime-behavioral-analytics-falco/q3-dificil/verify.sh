#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

STATE=/var/lib/cks-sim/22-q3
D=/opt/course/22/q3
LOCAL=/etc/falco/falco_rules.local.yaml
[ -f "$STATE/cid" ] || { echo "Estado do setup não encontrado. Rode: bash setup.sh"; exit 1; }
CID=$(cat "$STATE/cid")

# 1 - regra
if grep -q 'rule:[[:space:]]*Write below etc in container' "$LOCAL"; then
  ok "regra 'Write below etc in container' presente em $LOCAL"
else
  fail "regra 'Write below etc in container' não encontrada em $LOCAL"
fi
# extrai o bloco da regra
block=$(awk '/rule:[[:space:]]*Write below etc in container/{f=1; print; next} f && /^- /{f=0} f' "$LOCAL")
if echo "$block" | grep -Fq '%evt.time,%container.id,%container.image.repository,%user.uid,%proc.name'; then
  ok "output no formato pedido"
else
  fail "output da regra não está no formato %evt.time,%container.id,%container.image.repository,%user.uid,%proc.name"
fi
if echo "$block" | grep -Eiq '^[[:space:]]*priority:[[:space:]]*"?warning"?[[:space:]]*$'; then
  ok "priority WARNING"
else
  fail "priority não é WARNING"
fi
if echo "$block" | grep -q 'fd\.nam[[:space:]]'; then
  fail "a condição ainda usa o campo inexistente fd.nam"
fi

# 2 - serviço
SVC=""
for s in falco-modern-bpf falco-bpf falco-kmod falco-custom falco; do
  systemctl is-active --quiet "$s" 2>/dev/null && { SVC=$s; break; }
done
[ -n "$SVC" ] && ok "Falco rodando ($SVC)" || fail "nenhum serviço do Falco está ativo"

# 3 - log coletado
F=$D/falco.log
RE='[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+,[0-9a-f]{12},[^, ]+,[0-9]+,[^, ]+'
if [ -s "$F" ]; then
  n=$(grep -Ec "$RE" "$F")
  nc=$(grep -E "$RE" "$F" | grep -c ",$CID,")
  if [ "$n" -ge 4 ] && [ "$nc" -ge 4 ]; then
    ok "falco.log contém $n alertas no formato pedido ($nc do container suspeito)"
  else
    fail "falco.log tem poucos alertas no formato pedido (formato: $n, do container suspeito: $nc; esperado >= 4)"
  fi
  # janela de tempo coletada
  span=$(grep -Eo "$RE" "$F" | cut -d, -f1 | cut -d. -f1 | awk -F: '{s=$1*3600+$2*60+$3; if(NR==1)a=s; b=s} END{d=b-a; if(d<0)d+=86400; print d+0}')
  if [ "${span:-0}" -ge 20 ]; then ok "alertas cobrem ~${span}s de coleta"
  else fail "alertas cobrem só ${span:-0}s (colete por pelo menos 30s)"; fi
else
  fail "$F não existe ou está vazio"
fi

# 4 - pod
p=$(tr -d '[:space:]' < "$D/pod.txt" 2>/dev/null)
p=${p#pod/}
[ "$p" == "finance/ledger-worker" ] && ok "pod.txt correto" || fail "pod.txt incorreto ou ausente ($p)"

# 5 - exe
e=$(tr -d '[:space:]' < "$D/exe.txt" 2>/dev/null)
if [ "$e" == "/tmp/.cache/busybox" ] || [[ "$e" == */rootfs/tmp/.cache/busybox ]]; then ok "exe.txt correto"
else fail "exe.txt incorreto ou ausente ($e)"; fi

# 6 - remoção
if kubectl -n finance get pod ledger-worker >/dev/null 2>&1; then fail "Pod finance/ledger-worker ainda existe"
else ok "Pod finance/ledger-worker removido"; fi
for p in finance/ledger-api ops/backup ops/config-reader; do
  kubectl -n "${p%/*}" get pod "${p#*/}" >/dev/null 2>&1 && ok "$p preservado" || fail "$p foi removido (não deveria)"
done

finish
