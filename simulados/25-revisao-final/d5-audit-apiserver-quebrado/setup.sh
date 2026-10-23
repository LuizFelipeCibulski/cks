#!/usr/bin/env bash
D=$(dirname "$(readlink -f "$0")"); source "$D/../_lib.sh"
require_root; require_controlplane

apiserver_reset
ns_fresh d5
rm -rf /etc/kubernetes/audit /var/log/kubernetes/audit

info "Aplicando a mudança 'pela metade' do colega..."
awk '{print} /^    - kube-apiserver$/ {
  print "    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml"
  print "    - --audit-log-path=/var/log/kubernetes/audit/audit.log"
}' /root/cks-backup/kube-apiserver.yaml \
  | sed 's/--enable-admission-plugins=/--enable-admission-plugin=/' > /tmp/kas.yaml
grep -q audit-policy-file /tmp/kas.yaml || { echo "Formato inesperado do manifest; abortando"; exit 1; }
mv /tmp/kas.yaml "$MANIFEST"
sleep 5
echo; ok "Ambiente pronto (e o apiserver vai cair). Leia o enunciado.md"
echo "Para desistir e voltar ao original: cp /root/cks-backup/kube-apiserver.yaml $MANIFEST"
