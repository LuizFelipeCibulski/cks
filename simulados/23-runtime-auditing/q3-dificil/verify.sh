#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

STATE=/var/lib/cks-sim/23-q3
D=/opt/course/23/q3
POLICY=/etc/kubernetes/audit/policy.yaml
LOG=/var/log/kubernetes/audit/audit.log
[ -f "$STATE/time" ] || { echo "Estado do setup não encontrado. Rode: bash setup.sh"; exit 1; }
flag() { ps -eo args | grep -E '^(/usr/local/bin/)?kube-apiserver ' | head -1 | tr ' ' '\n' | grep -- "^--$1=" | head -1 | cut -d= -f2-; }
norm_sa() { sed 's/^system:serviceaccount://; s#/#:#'; }

if kubectl get --raw=/readyz >/dev/null 2>&1; then ok "kube-apiserver respondendo"
else fail "kube-apiserver não está respondendo"; finish; fi

# 1 - autor
u=$(tr -d '[:space:]' < "$D/user.txt" 2>/dev/null)
if [ "$u" == "system:serviceaccount:apps:ci-runner" ]; then ok "user.txt correto"
elif [ "$(echo "$u" | norm_sa)" == "apps:ci-runner" ]; then fail "user.txt identifica a SA certa, mas não no formato do audit log (system:serviceaccount:<ns>:<nome>)"
else fail "user.txt incorreto ou ausente ($u)"; fi

# 2 - timestamp
want=$(cat "$STATE/time")
t=$(tr -d '[:space:]"' < "$D/time.txt" 2>/dev/null)
if [ "$t" == "$want" ]; then ok "time.txt correto ($want)"
elif [ -n "$t" ] && [ "${t:0:19}" == "${want:0:19}" ]; then ok "time.txt correto (precisão de segundos)"
else fail "time.txt incorreto ou ausente (lido: '$t')"; fi

# 3 - leitores
if [ -f "$D/readers.txt" ]; then
  got=$(grep -v '^[[:space:]]*$' "$D/readers.txt" | tr -d '[:space:]"' | norm_sa | sort -u | tr '\n' ' ')
  exp="apps:ci-runner vault:backup-agent "
  [ "$got" == "$exp" ] && ok "readers.txt correto" || fail "readers.txt incorreto (lido: $got) — considere só gets com sucesso de ServiceAccounts"
else
  fail "$D/readers.txt não existe"
fi

# 4 - remediação
kubectl -n apps get sa ci-runner >/dev/null 2>&1 && fail "ServiceAccount apps/ci-runner ainda existe" || ok "ServiceAccount apps/ci-runner removida"
kubectl -n vault get rolebinding vault-maintenance >/dev/null 2>&1 && fail "RoleBinding vault/vault-maintenance (que dava acesso à SA) ainda existe" || ok "RoleBinding vault-maintenance removido"
[ "$(kubectl auth can-i patch secrets -n vault --as=system:serviceaccount:apps:ci-runner 2>/dev/null)" == "no" ] \
  && ok "apps:ci-runner não pode mais alterar secrets em vault" || fail "apps:ci-runner ainda pode alterar secrets em vault"
kubectl -n vault get sa backup-agent >/dev/null 2>&1 && kubectl -n vault get rolebinding backup >/dev/null 2>&1 \
  && [ "$(kubectl auth can-i get secret/db-credentials -n vault --as=system:serviceaccount:vault:backup-agent 2>/dev/null)" == "yes" ] \
  && ok "backup-agent mantém seu acesso" || fail "acesso da SA vault/backup-agent foi alterado (não deveria)"
kubectl -n vault get sa monitoring >/dev/null 2>&1 && kubectl -n apps get sa deployer >/dev/null 2>&1 \
  && ok "demais ServiceAccounts preservadas" || fail "outras ServiceAccounts foram removidas"

# 5..8 - policy nova em uso
[ "$(flag audit-policy-file)" == "$POLICY" ] && [ "$(flag audit-log-path)" == "$LOG" ] \
  && ok "apiserver usa $POLICY e grava em $LOG" || fail "flags de audit do apiserver alteradas/ausentes"
pid=$(pgrep -xo kube-apiserver)
if [ -n "$pid" ]; then
  start=$(date -d "$(ps -o lstart= -p "$pid")" +%s 2>/dev/null)
  mt=$(stat -c %Y "$POLICY" 2>/dev/null)
  [ -n "$start" ] && [ -n "$mt" ] && [ "$mt" -gt "$start" ] && \
    fail "a policy foi modificada DEPOIS que o kube-apiserver iniciou — reinicie o apiserver"
fi
[ -f "$LOG" ] || { fail "$LOG não existe"; finish; }

info "Gerando requisições de teste (≈10s)..."
kubectl -n vault delete secret cks-test --ignore-not-found >/dev/null 2>&1
kubectl -n vault delete cm cks-test --ignore-not-found >/dev/null 2>&1
sleep 2
OFF=$(stat -c %s "$LOG")
kubectl -n vault create secret generic cks-test --from-literal=x=y >/dev/null
kubectl -n vault get secret cks-test -o yaml >/dev/null
kubectl -n vault create cm cks-test --from-literal=x=y >/dev/null
kubectl -n vault get cm cks-test >/dev/null
kubectl -n vault get pods >/dev/null
kubectl -n vault delete cm cks-test >/dev/null
sleep 8
NEW=$(mktemp)
SIZE=$(stat -c %s "$LOG")
if [ "$SIZE" -ge "$OFF" ]; then tail -c +$((OFF + 1)) "$LOG" > "$NEW"; else cat "$LOG" > "$NEW"; fi

python3 - "$NEW" > "$NEW.res" <<'PYEOF'
import json, sys
evs = []
for l in open(sys.argv[1], errors="replace"):
    l = l.strip()
    if l.startswith("{"):
        try: evs.append(json.loads(l))
        except Exception: pass
def o(e): return e.get("objectRef") or {}
def out(ok, msg): print(("OK " if ok else "FAIL ") + msg)
if not evs:
    out(False, "nenhum evento novo no audit log"); sys.exit()

rr = [e for e in evs if e.get("stage") == "RequestReceived"]
out(not rr, "sem eventos RequestReceived" if not rr else f"{len(rr)} eventos no stage RequestReceived (falta omitStages)")

sec = [e for e in evs if o(e).get("resource") == "secrets" and o(e).get("name") == "cks-test"]
verbs = {e.get("verb") for e in sec}
if "create" in verbs and "get" in verbs:
    bad = [e for e in sec if e.get("level") != "Metadata" or "requestObject" in e or "responseObject" in e]
    out(not bad, "Secrets (create/get) registrados em Metadata, sem corpo" if not bad else "Secrets registrados com corpo/nível errado")
else:
    out(False, "create/get do Secret de teste não foram ambos registrados (a regra de Secrets deve vir antes da regra de get/list/watch)")

reads = [e for e in evs if e.get("verb") in ("get", "list", "watch") and o(e).get("resource") not in (None, "secrets")]
out(not reads, "get/list/watch de outros recursos não são registrados" if not reads
    else f"{len(reads)} eventos get/list/watch registrados (ex.: {reads[0].get('verb')} {o(reads[0]).get('resource')})")

cm = [e for e in evs if o(e).get("resource") == "configmaps" and o(e).get("name") == "cks-test" and e.get("verb") in ("create", "delete")]
if len(cm) >= 2:
    out(all(e.get("level") == "Metadata" for e in cm), "demais requisições em Metadata" if all(e.get("level") == "Metadata" for e in cm)
        else "create/delete de ConfigMap com nível " + ",".join(sorted({e.get('level') for e in cm})))
else:
    out(False, "create/delete de ConfigMap não registrados (falta o catch-all Metadata?)")

big = [e for e in evs if e.get("level") in ("Request", "RequestResponse")]
out(not big, "nenhum evento em Request/RequestResponse" if not big else f"{len(big)} eventos ainda em Request/RequestResponse")
PYEOF
while read -r st msg; do
  if [ "$st" == "OK" ]; then ok "$msg"; else fail "$msg"; fi
done < "$NEW.res"
rm -f "$NEW" "$NEW.res"
kubectl -n vault delete secret cks-test --ignore-not-found >/dev/null 2>&1

finish
