#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

POLICY=/etc/kubernetes/audit/policy.yaml
LOG=/var/log/kubernetes/audit/audit.log
flag() { ps -eo args | grep -E '^(/usr/local/bin/)?kube-apiserver ' | head -1 | tr ' ' '\n' | grep -- "^--$1=" | head -1 | cut -d= -f2-; }

if kubectl get --raw=/readyz >/dev/null 2>&1; then ok "kube-apiserver respondendo"
else fail "kube-apiserver não está respondendo"; finish; fi

[ "$(flag audit-policy-file)" == "$POLICY" ] && ok "apiserver usa $POLICY" || fail "--audit-policy-file alterado/ausente"
[ "$(flag audit-log-path)" == "$LOG" ] && ok "apiserver grava em $LOG" || fail "--audit-log-path alterado/ausente"

# o apiserver só lê a policy na inicialização
pid=$(pgrep -xo kube-apiserver)
if [ -n "$pid" ]; then
  start=$(date -d "$(ps -o lstart= -p "$pid")" +%s 2>/dev/null)
  mt=$(stat -c %Y "$POLICY" 2>/dev/null)
  if [ -n "$start" ] && [ -n "$mt" ] && [ "$mt" -gt "$start" ]; then
    fail "a policy foi modificada DEPOIS que o kube-apiserver iniciou — reinicie o apiserver para carregá-la"
  fi
fi

[ -f "$LOG" ] || { fail "$LOG não existe"; finish; }

info "Gerando requisições de teste (≈10s)..."
for o in "secret cks-sec -n audit-test" "cm cks-cm -n audit-test" "deploy cks-deploy -n prod" "deploy cks-deploy -n dev"; do
  kubectl delete $o --ignore-not-found >/dev/null 2>&1
done
sleep 2
OFF=$(stat -c %s "$LOG")

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
KCERT=/var/lib/kubelet/pki/kubelet-client-current.pem
kubectl create secret generic cks-sec -n audit-test --from-literal=password=s3cr3t >/dev/null
kubectl get secret cks-sec -n audit-test >/dev/null
kubectl create cm cks-cm -n audit-test --from-literal=a=b >/dev/null
kubectl create deploy cks-deploy -n prod --image=registry.k8s.io/pause:3.10 >/dev/null
kubectl create deploy cks-deploy -n dev --image=registry.k8s.io/pause:3.10 >/dev/null
kubectl get endpoints -n default >/dev/null 2>&1
# requisições com a identidade do kubelet (grupo system:nodes)
curl -s -o /dev/null --cacert /etc/kubernetes/pki/ca.crt --cert $KCERT --key $KCERT \
  "$SERVER/api/v1/namespaces/audit-test/secrets/cks-sec"
curl -s -o /dev/null --cacert /etc/kubernetes/pki/ca.crt --cert $KCERT --key $KCERT \
  "$SERVER/api/v1/namespaces/audit-test/pods"
curl -s -o /dev/null --cacert /etc/kubernetes/pki/ca.crt --cert $KCERT --key $KCERT \
  "$SERVER/api/v1/namespaces/audit-test/configmaps/cks-cm"
sleep 8

NEW=$(mktemp)
SIZE=$(stat -c %s "$LOG")
if [ "$SIZE" -ge "$OFF" ]; then tail -c +$((OFF + 1)) "$LOG" > "$NEW"; else cat "$LOG" > "$NEW"; fi

python3 - "$NEW" > "$NEW.res" <<'PYEOF'
import json, sys
evs = []
for l in open(sys.argv[1], errors="replace"):
    l = l.strip()
    if not l.startswith("{"):
        continue
    try:
        evs.append(json.loads(l))
    except Exception:
        pass

def res(e): return (e.get("objectRef") or {}).get("resource")
def name(e): return (e.get("objectRef") or {}).get("name")
def ns(e): return (e.get("objectRef") or {}).get("namespace")
def groups(e): return (e.get("user") or {}).get("groups") or []
def user(e): return (e.get("user") or {}).get("username", "")
def out(ok, msg): print(("OK " if ok else "FAIL ") + msg)

if not evs:
    out(False, "nenhum evento novo no audit log (o apiserver está auditando?)")
    sys.exit()

rr = [e for e in evs if e.get("stage") == "RequestReceived"]
out(not rr, "sem eventos no stage RequestReceived" if not rr else f"{len(rr)} eventos no stage RequestReceived (falta omitStages)")

sec = [e for e in evs if res(e) == "secrets" and name(e) == "cks-sec" and ns(e) == "audit-test" and not user(e).startswith("system:node:")]
if sec:
    bad = [e for e in sec if e.get("level") != "Metadata"]
    out(not bad, "Secrets (usuário comum) em nível Metadata" if not bad else "Secrets registrados com nível " + ",".join(sorted({e['level'] for e in bad})))
else:
    out(False, "requisições do admin ao Secret audit-test/cks-sec não foram registradas")

nsec = [e for e in evs if res(e) == "secrets" and name(e) == "cks-sec" and user(e).startswith("system:node:")]
if nsec:
    bad = [e for e in nsec if e.get("level") != "Metadata"]
    out(not bad, "get de Secret por system:nodes registrado em Metadata (ordem das regras correta)" if not bad else "get de Secret por node com nível errado")
else:
    out(False, "get de Secret feito por um node NÃO foi registrado — a regra de Secrets deve vir antes da regra de system:nodes")

nodes_reads = [e for e in evs if "system:nodes" in groups(e) and e.get("verb") in ("get", "list", "watch") and res(e) != "secrets"]
out(not nodes_reads, "get/list/watch de system:nodes não são registrados" if not nodes_reads
    else f"{len(nodes_reads)} eventos get/list/watch de system:nodes registrados (ex.: {nodes_reads[0].get('requestURI','')[:80]})")

ep = [e for e in evs if res(e) == "endpoints"]
out(not ep, "nenhum evento de endpoints" if not ep else f"{len(ep)} eventos de endpoints registrados")

dp = [e for e in evs if res(e) == "deployments" and name(e) == "cks-deploy" and ns(e) == "prod" and e.get("verb") == "create"]
if dp:
    out(all(e.get("level") == "RequestResponse" for e in dp), "Deployments em prod em RequestResponse" if all(e.get("level") == "RequestResponse" for e in dp)
        else "Deployments em prod com nível " + dp[-1].get("level", "?") + " (esperado RequestResponse; lembre do group 'apps')")
else:
    out(False, "create de Deployment em prod não registrado")

dd = [e for e in evs if res(e) == "deployments" and name(e) == "cks-deploy" and ns(e) == "dev" and e.get("verb") == "create"]
if dd:
    out(all(e.get("level") == "Metadata" for e in dd), "Deployments fora de prod em Metadata" if all(e.get("level") == "Metadata" for e in dd)
        else "Deployment em dev com nível " + dd[-1].get("level", "?") + " (esperado Metadata)")
else:
    out(False, "create de Deployment em dev não registrado (falta o catch-all Metadata?)")

cm = [e for e in evs if res(e) == "configmaps" and name(e) == "cks-cm" and e.get("verb") == "create"]
if cm:
    out(cm[-1].get("level") == "Metadata", "catch-all em Metadata (configmap)" if cm[-1].get("level") == "Metadata" else "configmap com nível " + cm[-1].get("level"))
else:
    out(False, "create de ConfigMap não registrado (falta o catch-all Metadata?)")
PYEOF
while read -r st msg; do
  if [ "$st" == "OK" ]; then ok "$msg"; else fail "$msg"; fi
done < "$NEW.res"
rm -f "$NEW" "$NEW.res"

kubectl delete deploy cks-deploy -n prod --ignore-not-found >/dev/null 2>&1
kubectl delete deploy cks-deploy -n dev --ignore-not-found >/dev/null 2>&1

finish
