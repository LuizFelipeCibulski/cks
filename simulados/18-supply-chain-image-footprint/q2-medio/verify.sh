#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

D=/opt/course/18/q2
F=$D/Dockerfile
IMG=app-q2:v1
TOKEN=$(cat /root/cks-backup/q18-2-token 2>/dev/null || echo 2e064aad-3a90-4cde-ad86-16fad1f8943e)
command -v docker >/dev/null || { fail "comando docker/podman não encontrado (rode o setup.sh)"; finish; }

# junta linhas com '\' para analisar instruções completas
J=$(sed -e ':a' -e '/\\$/N; s/\\\n/ /; ta' "$F")

from=$(echo "$J" | grep -iE '^\s*FROM' | tail -1 | awk '{print $2}')
echo "$from" | grep -qE '^(docker\.io/(library/)?)?ubuntu:24\.04$' && ok "FROM ubuntu:24.04" || fail "FROM deveria ser ubuntu:24.04 (achado: $from)"

if echo "$J" | grep -iE '^\s*RUN' | grep -q 'apt-get update' ; then
  upd_line=$(echo "$J" | grep -iE '^\s*RUN' | grep 'apt-get update')
  echo "$upd_line" | grep -qE 'apt-get[^&;|]* install' && ok "update e install na mesma instrução RUN" || fail "apt-get update e apt-get install devem estar no MESMO RUN"
  echo "$upd_line" | grep -q -- '--no-install-recommends' && ok "usa --no-install-recommends" || fail "use --no-install-recommends"
else
  fail "Nenhum RUN com apt-get update encontrado"
fi
[ "$(echo "$J" | grep -ciE '^\s*RUN.*apt-get update')" -le 1 ] || fail "há mais de um RUN com apt-get update"

if ! docker image inspect $IMG >/dev/null 2>&1; then
  fail "Imagem $IMG não encontrada"; finish
fi
ok "Imagem $IMG existe"

drun() { docker run --rm --entrypoint "$@" 2>/dev/null; }

n=$(drun sh $IMG -c 'ls /var/lib/apt/lists 2>/dev/null | grep -c _Packages')
[ "${n:-0}" = "0" ] && ok "Sem listas do apt em /var/lib/apt/lists" || fail "/var/lib/apt/lists ainda contém índices de pacotes"

drun sh $IMG -c 'command -v curl' >/dev/null && ok "curl disponível" || fail "curl deveria continuar instalado"
drun sh $IMG -c 'command -v vim || command -v vim.basic || command -v nc' >/dev/null && fail "vim/netcat ainda estão na imagem" || ok "vim/netcat não estão na imagem"
drun sh $IMG -c 'test -e /usr/bin/bash || test -e /bin/bash' && fail "bash ainda existe na imagem" || ok "bash removido"

uid=$(drun sh $IMG -c 'id -u'); un=$(drun sh $IMG -c 'id -un')
[ "$uid" = "10001" ] && [ "$un" = "app" ] && ok "Container roda como app (10001)" || fail "Container deveria rodar como app/10001 (achado: $un/$uid)"

leak=0
docker image inspect $IMG | grep -q "$TOKEN" && { leak=1; echo "   token encontrado em 'docker inspect' (ENV/labels)"; }
docker history --no-trunc $IMG 2>/dev/null | grep -q "$TOKEN" && { leak=1; echo "   token encontrado no histórico de camadas"; }
drun sh $IMG -c "grep -rqs '$TOKEN' /etc /root /home /tmp /opt 2>/dev/null" && { leak=1; echo "   token encontrado em arquivo da imagem"; }
grep -q "$TOKEN" "$F" && { leak=1; echo "   token ainda escrito no Dockerfile"; }
[ $leak -eq 0 ] && ok "Token não vaza na imagem" || fail "O token ainda vaza na imagem/Dockerfile"

grep -iE '^\s*CMD' "$F" | grep -q 'API_TOKEN' && grep -iE '^\s*CMD' "$F" | grep -q 'URL' \
  && ok "CMD continua usando \$URL e \$API_TOKEN" || fail "CMD deveria continuar usando \$URL e \$API_TOKEN"

finish
