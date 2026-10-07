#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/../../lib/common.sh"
require_root

# --- Garante um engine de containers (docker ou podman) ---
# Preferimos podman quando não há docker: o pacote docker.io traz outro containerd
# e pode conflitar com o containerd usado pelo kubelet.
ensure_engine() {
  if command -v docker >/dev/null 2>&1; then
    docker info >/dev/null 2>&1 || systemctl start docker >/dev/null 2>&1 || true
    docker info >/dev/null 2>&1 && return 0
  fi
  if ! command -v podman >/dev/null 2>&1; then
    info "Docker não encontrado: instalando podman..."
    apt-get update -qq >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y podman >/dev/null 2>&1
  fi
  command -v podman >/dev/null 2>&1 || { echo "Falha ao instalar podman"; exit 1; }
  mkdir -p /etc/containers/registries.conf.d
  cat > /etc/containers/registries.conf.d/99-cks.conf <<'EOF'
unqualified-search-registries = ["docker.io"]
short-name-mode = "permissive"
EOF
  command -v docker >/dev/null 2>&1 || ln -sf "$(command -v podman)" /usr/local/bin/docker
  hash -r
}
ensure_engine

info "Limpando tentativas anteriores..."
docker rm -f payments >/dev/null 2>&1
docker rmi -f payments:v1 payments:v2 >/dev/null 2>&1
rm -rf /opt/course/18/q3
mkdir -p /opt/course/18/q3/app
cd /opt/course/18/q3/app || exit 1

cat > go.mod <<'EOF'
module example.com/payments

go 1.22
EOF

cat > main.go <<'EOF'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})
	http.HandleFunc("/whoami", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "uid=%d\n", os.Getuid())
	})
	log.Println("payments escutando em :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF

cat > Dockerfile <<'EOF'
FROM golang:1.23-alpine
RUN apk add --no-cache bash curl git
WORKDIR /src
COPY . .
ENV GITHUB_TOKEN=ghp_Xk29fLq0aZr8PpT3vN7sWc1YhE5uJd4mB6oQ
RUN go build -o /usr/local/bin/payments .
EXPOSE 8080
CMD ["payments"]
EOF

info "Pré-baixando golang:1.23-alpine (pode demorar)..."
docker pull golang:1.23-alpine >/dev/null 2>&1 || true

info "Construindo a versão atual (payments:v1) para referência..."
docker build -t payments:v1 . >/dev/null 2>&1 || true
docker image ls 2>/dev/null | grep -E 'REPOSITORY|payments' || true

echo
echo "Ambiente pronto! Leia o enunciado.md"
