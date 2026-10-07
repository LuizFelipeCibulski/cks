#!/usr/bin/env bash
# Funções do controlplane para os simulados de gVisor (sourced pelos setup.sh/verify.sh deste componente).
GV_NODE_HELPER="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/gvisor-node.sh"

all_nodes() { kubectl get nodes --no-headers -o custom-columns=N:.metadata.name; }

is_local_node() {
  [ "$1" = "$(hostname)" ] || [ "$1" = "$(hostname -s)" ] || [ "$1" = "$(hostname -f 2>/dev/null)" ]
}

# on_node <node> <install|enable|restore|status>
on_node() {
  local n=$1; shift
  if is_local_node "$n"; then
    bash "$GV_NODE_HELPER" "$@"
  else
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes "$n" "bash -s -- $*" < "$GV_NODE_HELPER" \
      || { echo "AVISO: não foi possível executar '$*' no nó $n via ssh"; return 1; }
  fi
}

# nó alvo do exercício difícil: worker se existir, senão o controlplane
target_node() {
  local w; w=$(worker_node)
  [ -n "$w" ] && echo "$w" || all_nodes | head -1
}
