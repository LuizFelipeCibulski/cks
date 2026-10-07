#!/usr/bin/env bash
# Network Policies — Q3 (Difícil): verificação
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# reach <ns> <alvo-exec> <url>
reach() { timeout 15 kubectl -n "$1" exec "$2" -- wget -qO- -T 3 "$3" 2>/dev/null | grep -q .; }
dns()   { timeout 20 kubectl -n "$1" exec "$2" -- nslookup "$3" 2>/dev/null | grep -qi "^name:"; }
podip() { kubectl -n "$1" get pod -l "app=$2" -o jsonpath='{.items[0].status.podIP}'; }

WEB=http://web.frontend.svc.cluster.local
API=http://api.backend.svc.cluster.local:8080
DB=http://db.database.svc.cluster.local:5432
WEB_IP=$(podip frontend web); API_IP=$(podip backend api); DB_IP=$(podip database db)

echo "== Estrutura"
for ns in frontend backend database; do
  if ! kubectl -n "$ns" get networkpolicy default-deny >/dev/null 2>&1; then
    fail "$ns: NetworkPolicy default-deny não existe"; continue
  fi
  sel=$(kubectl -n "$ns" get networkpolicy default-deny -o jsonpath='{.spec.podSelector}')
  types=$(kubectl -n "$ns" get networkpolicy default-deny -o jsonpath='{.spec.policyTypes[*]}')
  rules=$(kubectl -n "$ns" get networkpolicy default-deny -o jsonpath='{.spec.ingress}{.spec.egress}' | sed 's/\[\]//g')
  if { [ -z "$sel" ] || [ "$sel" = "{}" ]; } && [[ " $types " == *" Ingress "* ]] && [[ " $types " == *" Egress "* ]] && [ -z "$rules" ]; then
    ok "$ns: default-deny bloqueia Ingress e Egress de todos os Pods"
  else
    fail "$ns: default-deny deve ter podSelector {}, policyTypes [Ingress, Egress] e nenhuma regra"
  fi
done

# ipBlock 1.1.1.1/32:443 para app=api e nenhum ipBlock mais amplo no backend
kubectl -n backend get networkpolicy -o json | python3 -c '
import json, sys
d = json.load(sys.stdin)
found, broad = False, []
for p in d["items"]:
    s = p["spec"]
    labels = (s.get("podSelector") or {}).get("matchLabels") or {}
    exprs = (s.get("podSelector") or {}).get("matchExpressions")
    applies = (not labels and not exprs) or labels.get("app") == "api" or bool(exprs)
    for r in s.get("egress") or []:
        for t in r.get("to") or []:
            ib = t.get("ipBlock")
            if not ib:
                continue
            if ib.get("cidr") != "1.1.1.1/32":
                broad.append(p["metadata"]["name"] + ":" + ib.get("cidr", ""))
            elif applies and any(str(x.get("port")) == "443" and x.get("protocol", "TCP") == "TCP" for x in (r.get("ports") or [])):
                found = True
if broad:
    print("broad:" + ",".join(broad)); sys.exit(2)
sys.exit(0 if found else 1)
'
rc=$?
case $rc in
  0) ok "backend: egress ipBlock 1.1.1.1/32 TCP/443 para app=api" ;;
  2) fail "backend: existe ipBlock diferente de 1.1.1.1/32 (abre mais do que o necessário)" ;;
  *) fail "backend: não encontrei egress ipBlock 1.1.1.1/32 porta TCP 443 para Pods app=api" ;;
esac

echo "== DNS"
for t in frontend/deploy/web frontend/deploy/debug backend/deploy/api backend/deploy/batch database/deploy/db; do
  ns=${t%%/*}; target=${t#*/}
  if dns "$ns" "$target" kubernetes.default.svc.cluster.local; then ok "$ns/${target#deploy/} resolve DNS"; else fail "$ns/${target#deploy/} não resolve DNS"; fi
done

echo "== Fluxos permitidos"
if reach cks-probe probe "$WEB"; then ok "qualquer origem (cks-probe) → web:80"; else fail "cks-probe → web:80 deveria funcionar"; fi
if reach frontend deploy/web "$API"; then ok "web → api:8080 (por nome)"; else fail "web → api:8080 deveria funcionar"; fi
if reach backend deploy/api "$DB"; then ok "api → db:5432 (por nome)"; else fail "api → db:5432 deveria funcionar"; fi

echo "== Fluxos bloqueados"
check_block() { # descrição ns alvo url
  if reach "$2" "$3" "$4"; then fail "$1 deveria estar BLOQUEADO"; else ok "$1 bloqueado"; fi
}
check_block "cks-probe → api"      cks-probe probe        "http://$API_IP:8080"
check_block "cks-probe → db"       cks-probe probe        "http://$DB_IP:5432"
check_block "web → db"             frontend  deploy/web   "http://$DB_IP:5432"
check_block "debug → api"          frontend  deploy/debug "http://$API_IP:8080"
check_block "batch → db"           backend   deploy/batch "http://$DB_IP:5432"
check_block "batch → api"          backend   deploy/batch "http://$API_IP:8080"
check_block "api → web"            backend   deploy/api   "http://$WEB_IP"
check_block "db → api"             database  deploy/db    "http://$API_IP:8080"

if kubectl -n database get networkpolicy allow-all-legacy >/dev/null 2>&1; then
  ing=$(kubectl -n database get networkpolicy allow-all-legacy -o jsonpath='{.spec.ingress}')
  [[ "$ing" == *"{}"* ]] && fail "database: a política allow-all-legacy ainda libera todo o ingress"
fi

finish
