#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/19/q2

# 1) arquivos inseguros
exp="Dockerfile-2 Dockerfile-3 deploy-b.yaml"
if [ -s $D/insecure-files.txt ]; then
  got=$(sed 's#.*/##; s/[[:space:]]//g' $D/insecure-files.txt | grep -v '^$' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')
  n_ok=0
  for f in $exp; do echo " $got " | grep -q " $f " && n_ok=$((n_ok+1)); done
  extra=$(for g in $got; do echo " $exp " | grep -q " $g " || echo "$g"; done | tr '\n' ' ')
  if [ $n_ok -eq 3 ] && [ -z "$extra" ]; then ok "insecure-files.txt correto"
  else fail "insecure-files.txt incorreto: $n_ok/3 arquivos inseguros identificados${extra:+; arquivos listados que estão OK: $extra}"; fi
else
  fail "$D/insecure-files.txt ausente"
fi

# 2) saída do kube-linter
if [ -s $D/kube-linter-b.txt ] && grep -q 'host-pid' $D/kube-linter-b.txt && grep -q 'sensitive-host-mounts' $D/kube-linter-b.txt; then
  ok "kube-linter-b.txt contém os achados do kube-linter para deploy-b.yaml"
else
  fail "kube-linter-b.txt ausente ou não contém a saída do kube-linter (configuração padrão) para deploy-b.yaml"
fi

# 3) Dockerfile-3 corrigido
F=$D/Dockerfile-3
code=$(grep -vE '^\s*#' $F)
if echo "$code" | grep -E 'id_rsa|id_ed25519|\.ssh' | grep -vq -- '--mount=type=s'; then
  fail "Dockerfile-3 ainda copia/usa uma chave privada dentro da imagem"
else
  ok "Dockerfile-3 não copia chave privada para a imagem"
fi
lastuser=$(echo "$code" | grep -iE '^\s*USER\s' | tail -1 | awk '{print $2}')
if [ -n "$lastuser" ] && ! echo "$lastuser" | grep -qE '^(root|0)(:.*)?$'; then ok "Último USER do Dockerfile-3 é não-root ($lastuser)"
else fail "O processo final do Dockerfile-3 ainda roda como root (último USER: ${lastuser:-nenhum})"; fi
from=$(echo "$code" | grep -iE '^\s*FROM' | head -1 | awk '{print $2}')
[ "$from" = "node:20.11-alpine" ] && ok "Imagem base mantida" || fail "A imagem base deve continuar node:20.11-alpine"
echo "$code" | grep -qE '^\s*CMD \["node", ?"server.js"\]' && ok "CMD mantido" || fail "O CMD deve continuar [\"node\", \"server.js\"]"

finish
