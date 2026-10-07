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
docker rm -f q1 >/dev/null 2>&1
docker rmi -f app-q1:v1 >/dev/null 2>&1
rm -rf /opt/course/18/q1
mkdir -p /opt/course/18/q1

cat > /opt/course/18/q1/Dockerfile <<'EOF'
FROM alpine

RUN adduser -D -g '' appuser

CMD ["sh", "-c", "sleep 1d"]
EOF

info "Pré-baixando alpine:3.20.3..."
docker pull alpine:3.20.3 >/dev/null 2>&1 || true

echo
echo "Ambiente pronto! Leia o enunciado.md"
