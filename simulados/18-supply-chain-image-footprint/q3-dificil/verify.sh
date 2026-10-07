#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

F=/opt/course/18/q3/app/Dockerfile
IMG=payments:v2
MAX=$((20*1024*1024))
command -v docker >/dev/null || { fail "comando docker/podman não encontrado (rode o setup.sh)"; finish; }

# ---------- Dockerfile ----------
froms=$(grep -iE '^\s*FROM' "$F" | awk '{print $2}')
nfrom=$(echo "$froms" | grep -c .)
[ "$nfrom" -ge 2 ] && ok "Dockerfile multi-stage ($nfrom estágios)" || fail "Dockerfile deveria ser multi-stage (2+ FROM)"

first=$(echo "$froms" | head -1); last=$(echo "$froms" | tail -1)
if echo "$first" | grep -qiE 'golang:[^ ]+' && ! echo "$first" | grep -qiE ':latest$'; then
  ok "Estágio de build com imagem Go de tag fixa ($first)"
else
  fail "Estágio de build deveria usar golang:<tag fixa> (achado: $first)"
fi
if echo "$last" | grep -qiE '^(scratch|gcr\.io/distroless/)'; then ok "Estágio final mínimo ($last)"
else fail "Estágio final deveria ser scratch ou gcr.io/distroless/... (achado: $last)"; fi
echo "$last" | grep -qi ':debug' && fail "Imagens distroless ':debug' contêm shell (busybox)"

# ---------- Imagem ----------
if ! docker image inspect $IMG >/dev/null 2>&1; then fail "Imagem $IMG não encontrada"; finish; fi
ok "Imagem $IMG existe"

size=$(docker image inspect -f '{{.Size}}' $IMG)
[ "$size" -lt "$MAX" ] && ok "Tamanho da imagem: $((size/1024/1024)) MB (< 20 MB)" || fail "Imagem com $((size/1024/1024)) MB (precisa ser < 20 MB)"

shell=0
for s in /bin/sh /bin/bash /bin/ash /busybox/sh /usr/bin/sh; do
  docker run --rm --entrypoint "$s" $IMG -c 'exit 0' >/dev/null 2>&1 && { shell=1; echo "   shell encontrado: $s"; }
done
[ $shell -eq 0 ] && ok "Imagem final sem shell" || fail "Imagem final ainda contém shell"

user=$(docker image inspect -f '{{.Config.User}}' $IMG)
if [ -n "$user" ] && ! echo "$user" | grep -qE '^(0|root)(:.*)?$'; then ok "USER da imagem: $user"
else fail "Imagem deveria definir USER não-root (achado: '$user')"; fi

leak=0
docker image inspect $IMG | grep -q 'ghp_' && leak=1
docker history --no-trunc $IMG 2>/dev/null | grep -q 'ghp_' && leak=1
[ $leak -eq 0 ] && ok "Sem credencial (GITHUB_TOKEN) na imagem" || fail "Credencial GITHUB_TOKEN ainda presente na imagem (ENV/histórico)"

# ---------- Container ----------
img=$(docker ps --filter name='^payments$' --format '{{.Image}}' 2>/dev/null)
echo "$img" | grep -q 'payments:v2' && ok "Container payments rodando com $IMG" || fail "Container 'payments' deveria estar rodando a partir de $IMG"

h=$(curl -s -m3 http://127.0.0.1:18080/healthz)
[ "$h" = "ok" ] && ok "GET :18080/healthz -> ok" || fail "GET http://127.0.0.1:18080/healthz não respondeu 'ok' (resposta: '$h')"
w=$(curl -s -m3 http://127.0.0.1:18080/whoami)
if echo "$w" | grep -qE '^uid=[1-9][0-9]*'; then ok "Processo roda como não-root ($w)"
else fail "/whoami deveria retornar uid diferente de 0 (resposta: '$w')"; fi

finish
