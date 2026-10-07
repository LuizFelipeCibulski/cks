#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

info "Recriando namespaces legacy e monitoring..."
ns_fresh legacy
ns_fresh monitoring
rm -rf /opt/course/15/q2 && mkdir -p /opt/course/15/q2

kubectl -n legacy create secret generic app-config --from-literal=url=https://legacy.internal --from-literal=password=n0t-th1s-0ne >/dev/null
kubectl -n legacy create secret generic db-auth --from-literal=username=sa --from-literal=admin-password='L3g4cy-Adm!n-2019' >/dev/null
kubectl -n legacy create secret generic smtp --from-literal=user=mailer --from-literal=pass=m4il3r >/dev/null
kubectl -n legacy create secret docker-registry registry-creds --docker-server=registry.legacy.internal --docker-username=ci --docker-password=ci-pass >/dev/null

kubectl -n monitoring create sa agent-sa >/dev/null
kubectl -n monitoring create secret generic grafana-admin --from-literal=DB_PASS=decoy-value >/dev/null
kubectl -n monitoring create secret generic mon-store-7f3a --from-literal=p='Pr0m-St0r3#42' >/dev/null
kubectl apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: agent
  namespace: monitoring
  labels: {app: agent}
spec:
  serviceAccountName: agent-sa
  containers:
  - name: agent
    image: busybox:1.36
    command: ["sh", "-c", "sleep 1d"]
    env:
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: mon-store-7f3a
          key: p
    - name: DB_HOST
      value: tsdb.monitoring.svc
YAML
wait_pods monitoring
echo
echo "Ambiente pronto! Leia o enunciado.md"
