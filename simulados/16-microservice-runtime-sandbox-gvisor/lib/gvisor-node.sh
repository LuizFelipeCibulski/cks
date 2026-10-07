#!/usr/bin/env bash
# Helper executado EM CADA NÓ (localmente ou via "ssh <node> bash -s -- <cmd> < gvisor-node.sh").
# Comandos:
#   install  -> instala runsc + containerd-shim-runsc-v1 em /usr/local/bin (não mexe no containerd)
#   enable   -> registra o handler "runsc" no containerd SEM sobrescrever o config.toml (append seguro)
#   restore  -> volta o config.toml ao original (backup em /root/cks-backup) e remove o handler runsc
#   status   -> mostra se runsc está instalado/registrado
set -u
CFG=/etc/containerd/config.toml
BKDIR=/root/cks-backup
BK=$BKDIR/containerd-config.toml
ABSENT=$BKDIR/containerd-config.toml.absent
MARK="# cks-simulado: runtime gVisor (runsc)"
H=$(hostname)
log() { echo "[$H] $*"; }

# Guarda o config original uma única vez (antes de qualquer alteração dos simulados)
snapshot() {
  mkdir -p "$BKDIR"
  [ -f "$BK" ] || [ -f "$ABSENT" ] && return 0
  if [ -f "$CFG" ]; then cp -a "$CFG" "$BK"; else touch "$ABSENT"; fi
}

restart_containerd() {
  systemctl restart containerd
  for _ in $(seq 1 30); do crictl info >/dev/null 2>&1 && return 0; sleep 1; done
  log "AVISO: containerd não respondeu após restart"; return 1
}

install() {
  if [ -x /usr/local/bin/runsc ] && [ -x /usr/local/bin/containerd-shim-runsc-v1 ]; then
    log "gVisor já instalado ($(/usr/local/bin/runsc --version 2>/dev/null | head -1))"; return 0
  fi
  local arch tmp rel url ok=0
  arch=$(uname -m); tmp=$(mktemp -d)
  for rel in latest 20230925; do
    url=https://storage.googleapis.com/gvisor/releases/release/$rel/$arch
    log "Baixando gVisor ($rel)..."
    ( cd "$tmp" && rm -f ./* && \
      curl -fsSLO "$url/runsc" && curl -fsSLO "$url/runsc.sha512" && \
      curl -fsSLO "$url/containerd-shim-runsc-v1" && curl -fsSLO "$url/containerd-shim-runsc-v1.sha512" && \
      sha512sum -c runsc.sha512 -c containerd-shim-runsc-v1.sha512 >/dev/null ) && { ok=1; break; }
  done
  if [ $ok -ne 1 ]; then log "ERRO: falha ao baixar o gVisor"; rm -rf "$tmp"; return 1; fi
  chmod a+rx "$tmp/runsc" "$tmp/containerd-shim-runsc-v1"
  mv "$tmp/runsc" "$tmp/containerd-shim-runsc-v1" /usr/local/bin/
  rm -rf "$tmp"
  log "instalado: $(/usr/local/bin/runsc --version 2>/dev/null | head -1)"
}

# versão do formato do config.toml: 3 (containerd 2.x), 2 (containerd 1.x) ou 1 (legado, sem "version")
cfg_version() {
  local v
  v=$(grep -E '^[[:space:]]*version[[:space:]]*=' "$CFG" 2>/dev/null | head -1 | grep -oE '[0-9]+')
  if [ -n "$v" ]; then echo "$v"; return; fi
  if grep -qE '^[[:space:]]*\[' "$CFG" 2>/dev/null; then echo 1; return; fi   # tem tabelas mas sem version -> v1
  if containerd --version 2>/dev/null | grep -qE '[[:space:]]v?2\.[0-9]+'; then echo 3; else echo 2; fi
}

runsc_registered() { grep -qE "runtimes\.[\"']?runsc[\"']?\][[:space:]]*$" "$CFG" 2>/dev/null; }

enable() {
  snapshot
  mkdir -p /etc/containerd
  if runsc_registered; then log "handler runsc já registrado no containerd"; return 0; fi
  local v sec
  v=$(cfg_version)
  if [ ! -s "$CFG" ]; then
    printf 'version = %s\n' "$v" > "$CFG"
  fi
  case $v in
    3) sec="[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]" ;;
    2) sec='[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]' ;;
    *) sec='[plugins.cri.containerd.runtimes.runsc]' ;;
  esac
  printf '\n%s\n%s\n  runtime_type = "io.containerd.runsc.v1"\n' "$MARK" "$sec" >> "$CFG"
  log "handler runsc adicionado ao $CFG (config version $v)"
  restart_containerd
}

restore() {
  if [ -f "$BK" ]; then
    cmp -s "$BK" "$CFG" || { cp -a "$BK" "$CFG"; log "config.toml original restaurado"; restart_containerd; }
  elif [ -f "$ABSENT" ]; then
    [ -f "$CFG" ] && { rm -f "$CFG"; log "config.toml removido (não existia originalmente)"; restart_containerd; }
  elif grep -qF "$MARK" "$CFG" 2>/dev/null; then
    # sem backup, mas com o bloco que o simulado adicionou: remove só o bloco
    awk -v m="$MARK" '$0==m{skip=3} skip>0{skip--; next} {print}' "$CFG" > "$CFG.tmp" && cat "$CFG.tmp" > "$CFG" && rm -f "$CFG.tmp"
    restart_containerd
  fi
  snapshot
  if runsc_registered; then log "AVISO: o config.toml original já registra runsc"; fi
  return 0
}

status() {
  echo "[$H] runsc: $(command -v runsc || echo ausente) | shim: $( [ -x /usr/local/bin/containerd-shim-runsc-v1 ] && echo ok || echo ausente) | registrado: $(runsc_registered && echo sim || echo não) | config v$(cfg_version)"
}

case "${1:-status}" in
  install|enable|restore|status) "$1" ;;
  *) echo "uso: $0 install|enable|restore|status"; exit 1 ;;
esac
