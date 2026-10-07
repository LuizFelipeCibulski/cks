#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

NS=vault-app
d() { kubectl -n $NS get secret db-credentials -o jsonpath="{.data.$1}" 2>/dev/null | base64 -d 2>/dev/null; }
[ "$(kubectl -n $NS get secret db-credentials -o jsonpath='{.type}' 2>/dev/null)" = "Opaque" ] && ok "Secret db-credentials (Opaque) existe" || fail "Secret genérico db-credentials não existe"
[ "$(d username)" = "appuser" ] && ok "username correto" || fail "username incorreto ('$(d username)')"
[ "$(d password)" = 'Sup3r-S3cr3t!' ] && ok "password correto" || fail "password incorreto ('$(d password)') — cuidado com o '!' no bash e com quebra de linha"

[ "$(kubectl -n $NS get pod app -o jsonpath='{.status.phase}' 2>/dev/null)" = "Running" ] && ok "Pod app Running" || { fail "Pod app não está Running"; finish; }

[ "$(kubectl -n $NS exec app -- sh -c 'echo -n "$DB_USER"' 2>/dev/null)" = "appuser" ] && ok "DB_USER=appuser no container" || fail "variável DB_USER ausente/incorreta"
kubectl -n $NS get pod app -o jsonpath='{.spec.containers[0].env[?(@.name=="DB_USER")].valueFrom.secretKeyRef.name}' | grep -qx db-credentials \
  && ok "DB_USER vem de secretKeyRef" || fail "DB_USER deve vir de secretKeyRef do Secret db-credentials"

[ "$(kubectl -n $NS exec app -- cat /etc/db-credentials/password 2>/dev/null)" = 'Sup3r-S3cr3t!' ] && ok "Secret montado em /etc/db-credentials" || fail "/etc/db-credentials/password não contém a senha"
[ "$(kubectl -n $NS exec app -- cat /etc/db-credentials/username 2>/dev/null)" = 'appuser' ] && ok "Chave username montada" || fail "/etc/db-credentials/username ausente"
kubectl -n $NS exec app -- sh -c 'touch /etc/db-credentials/x' >/dev/null 2>&1 && fail "volume está gravável" || ok "volume somente leitura"
vol=$(kubectl -n $NS get pod app -o jsonpath='{.spec.volumes[?(@.secret.secretName=="db-credentials")].name}')
ro=$(kubectl -n $NS get pod app -o jsonpath="{.spec.containers[0].volumeMounts[?(@.name==\"$vol\")].readOnly}")
[ "$ro" = "true" ] && ok "volumeMount readOnly: true" || fail "volumeMount do secret deve ter readOnly: true"

finish
