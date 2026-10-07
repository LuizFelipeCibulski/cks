#!/usr/bin/env bash
# Secure Ingress — SETUP
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root
require_controlplane

# ---------------------------------------------------------------------------
# Helpers locais de ingress (repetidos em cada setup desta pasta)
# ---------------------------------------------------------------------------
ING_VERSION="controller-v1.12.1"
ING_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${ING_VERSION}/deploy/static/provider/baremetal/deploy.yaml"

# Garante um ingress-nginx funcional e descobre ING_NS, ING_SVC, HTTP_PORT, HTTPS_PORT e NODE_IP
ensure_ingress_nginx() {
  if ! kubectl get ingressclass nginx >/dev/null 2>&1; then
    info "ingress-nginx não encontrado — instalando ${ING_VERSION} (manifest baremetal oficial)..."
    kubectl apply -f "$ING_MANIFEST" >/dev/null || { echo "Falha ao instalar ingress-nginx"; exit 1; }
    # Em cluster sem worker o controller precisa tolerar o taint do controlplane
    kubectl -n ingress-nginx patch deploy ingress-nginx-controller --type=json \
      -p='[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}]' >/dev/null 2>&1 || true
  fi

  local line
  line=$(kubectl get svc -A -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller \
          --no-headers -o custom-columns=NS:.metadata.namespace,N:.metadata.name 2>/dev/null | grep -v admission | head -1)
  ING_NS=$(echo "$line" | awk '{print $1}'); ING_SVC=$(echo "$line" | awk '{print $2}')
  [ -z "$ING_SVC" ] && { echo "Service do ingress-nginx controller não encontrado"; exit 1; }

  info "Aguardando ingress-nginx controller ficar Ready (ns $ING_NS)..."
  kubectl -n "$ING_NS" wait --for=condition=complete job --all --timeout=180s >/dev/null 2>&1 || true
  for _ in $(seq 1 60); do
    kubectl -n "$ING_NS" get pod -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -q . && break
    sleep 2
  done
  kubectl -n "$ING_NS" wait --for=condition=Ready pod -l app.kubernetes.io/component=controller --timeout=300s >/dev/null \
    || { echo "ingress-nginx controller não ficou Ready"; exit 1; }

  if [ "$(kubectl -n "$ING_NS" get svc "$ING_SVC" -o jsonpath='{.spec.type}')" = "ClusterIP" ]; then
    kubectl -n "$ING_NS" patch svc "$ING_SVC" -p '{"spec":{"type":"NodePort"}}' >/dev/null
  fi
  HTTP_PORT=$(kubectl -n "$ING_NS" get svc "$ING_SVC" -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
  HTTPS_PORT=$(kubectl -n "$ING_NS" get svc "$ING_SVC" -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
  NODE_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
}

# kubectl apply com retry (o webhook de admissão do ingress-nginx pode demorar a responder)
apply_retry() {
  for _ in $(seq 1 30); do
    kubectl apply -f "$1" >/dev/null 2>&1 && return 0
    sleep 3
  done
  kubectl apply -f "$1"
}

# Backend nginx que responde "backend=<nome>" em qualquer path (porta 8080, Service porta 80)
make_backend() {
  local ns=$1 n=$2
  kubectl -n "$ns" create configmap "$n-conf" \
    --from-literal=default.conf="server { listen 8080; location / { default_type text/plain; return 200 \"backend=$n\n\"; } }" >/dev/null
  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $n
  namespace: $ns
  labels:
    app: $n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $n
  template:
    metadata:
      labels:
        app: $n
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: conf
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: conf
        configMap:
          name: $n-conf
---
apiVersion: v1
kind: Service
metadata:
  name: $n
  namespace: $ns
spec:
  selector:
    app: $n
  ports:
  - name: http
    port: 80
    targetPort: 8080
YAML
}
# ---------------------------------------------------------------------------

ensure_ingress_nginx

info "Recriando namespace secure-web..."
ns_fresh secure-web
make_backend secure-web web

info "Gerando certificado em /opt/course/ingress1 ..."
rm -rf /opt/course/ingress1
mkdir -p /opt/course/ingress1
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /opt/course/ingress1/tls.key -out /opt/course/ingress1/tls.crt \
  -subj "/CN=web.cks.local/O=cks" -addext "subjectAltName=DNS:web.cks.local" >/dev/null 2>&1

cat > /tmp/cks-ing1.yaml <<'YAML'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: secure-web
spec:
  ingressClassName: nginx
  rules:
  - host: web.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
YAML
apply_retry /tmp/cks-ing1.yaml
rm -f /tmp/cks-ing1.yaml
wait_pods secure-web

echo
info "ingress-nginx: HTTP NodePort=$HTTP_PORT  HTTPS NodePort=$HTTPS_PORT  IP do controlplane=$NODE_IP"
echo "Ambiente pronto! Leia o enunciado.md"
