#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# --- KubeLinter (release oficial, versão fixa) ---
install_kube_linter() {
  command -v kube-linter >/dev/null && return 0
  info "Instalando kube-linter v0.8.3..."
  curl -fsSL https://github.com/stackrox/kube-linter/releases/download/v0.8.3/kube-linter-linux.tar.gz \
    | tar xz -C /usr/local/bin kube-linter
  chmod +x /usr/local/bin/kube-linter
}
install_kube_linter
command -v kube-linter >/dev/null || { echo "Falha ao instalar kube-linter"; exit 1; }

rm -rf /opt/course/19/q2
mkdir -p /opt/course/19/q2
cd /opt/course/19/q2 || exit 1

cat > deploy-a.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inventory
  labels:
    app: inventory
spec:
  replicas: 1
  selector:
    matchLabels:
      app: inventory
  template:
    metadata:
      labels:
        app: inventory
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: registry.k8s.io/pause:3.10
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 32Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
EOF

cat > deploy-b.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-shipper
  labels:
    app: log-shipper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: log-shipper
  template:
    metadata:
      labels:
        app: log-shipper
    spec:
      hostPID: true
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
      - name: shipper
        image: busybox:1.36
        command: ["sh", "-c", "tail -F /host/var/log/syslog"]
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 64Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop: ["ALL"]
        volumeMounts:
        - name: host
          mountPath: /host
      volumes:
      - name: host
        hostPath:
          path: /
EOF

cat > pod-c.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: report-job
  labels:
    app: report-job
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 10002
    runAsGroup: 10002
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: report
    image: busybox:1.36
    command: ["sh", "-c", "echo gerando relatorio; sleep 3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: report-db
          key: password
    resources:
      requests:
        cpu: 10m
        memory: 16Mi
      limits:
        cpu: 100m
        memory: 32Mi
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
EOF

cat > Dockerfile-1 <<'EOF'
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER 65532:65532
ENTRYPOINT ["/app"]
EOF

cat > Dockerfile-2 <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
ENV AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
RUN useradd -u 10001 -M app
USER 10001
CMD ["python", "main.py"]
EOF

cat > Dockerfile-3 <<'EOF'
FROM node:20.11-alpine
WORKDIR /app
COPY package.json package-lock.json ./
# chave de deploy para baixar dependencias do repositorio git privado
COPY id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa && npm ci --omit=dev
COPY . .
RUN chown -R node:node /app
USER node
EXPOSE 3000
# o time de ops pediu acesso total dentro do container para debug
USER root
CMD ["node", "server.js"]
EOF

echo
echo "Ambiente pronto! Leia o enunciado.md"
