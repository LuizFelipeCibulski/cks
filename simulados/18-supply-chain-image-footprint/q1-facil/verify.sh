#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/18/q1
command -v docker >/dev/null || { fail "comando docker/podman não encontrado (rode o setup.sh)"; finish; }

from=$(grep -iE '^\s*FROM' $D/Dockerfile | tail -1 | awk '{print $2}')
echo "$from" | grep -qE '^(docker\.io/(library/)?)?alpine:3\.20\.3$' \
  && ok "Dockerfile usa alpine:3.20.3" || fail "Dockerfile deveria usar FROM alpine:3.20.3 (achado: $from)"

grep -qiE '^\s*USER\s+appuser\s*$' $D/Dockerfile \
  && ok "Dockerfile define USER appuser" || fail "Dockerfile deveria ter 'USER appuser'"

if docker image inspect app-q1:v1 >/dev/null 2>&1; then
  ok "Imagem app-q1:v1 existe"
  u=$(docker image inspect -f '{{.Config.User}}' app-q1:v1)
  [ "$u" = "appuser" ] && ok "Config.User da imagem = appuser" || fail "Config.User da imagem deveria ser appuser (achado: '$u')"
  run=$(docker run --rm app-q1:v1 id -un 2>/dev/null)
  [ "$run" = "appuser" ] && ok "Container roda como appuser" || fail "Container roda como '$run'"
else
  fail "Imagem app-q1:v1 não encontrada (buildou com a tag certa?)"
fi

img=$(docker ps --filter name='^q1$' --format '{{.Image}}' 2>/dev/null)
echo "$img" | grep -q 'app-q1:v1' && ok "Container q1 rodando com app-q1:v1" || fail "Container q1 deveria estar rodando a partir de app-q1:v1"

if [ -s $D/ps.txt ] && grep -q 'sleep' $D/ps.txt && grep -q 'appuser' $D/ps.txt && ! grep -qE '^\s*1\s+root' $D/ps.txt; then
  ok "ps.txt mostra os processos rodando como appuser"
else
  fail "$D/ps.txt ausente ou não mostra os processos (sleep) do usuário appuser"
fi

finish
