#!/bin/bash
# =============================================================================
# down.sh — Destroi o cluster inteiro (todos os containers do k3d somem).
# Os dados (PVCs) vão junto, a menos que você tenha configurado storage
# externo. Use com consciência.
# =============================================================================

set -euo pipefail

CLUSTER_NAME="devops-lab"

read -p "Isso vai apagar o cluster '${CLUSTER_NAME}' e TODOS os dados dentro dele. Confirma? (digite 'sim'): " CONFIRM
if [ "$CONFIRM" != "sim" ]; then
  echo "Cancelado."
  exit 0
fi

k3d cluster delete "${CLUSTER_NAME}"
echo "✅ Cluster removido."
