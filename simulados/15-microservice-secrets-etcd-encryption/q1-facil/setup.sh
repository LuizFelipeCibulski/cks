#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespace vault-app..."
ns_fresh vault-app
echo
echo "Ambiente pronto! Leia o enunciado.md"
