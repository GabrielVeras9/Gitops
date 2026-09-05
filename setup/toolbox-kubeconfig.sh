#!/bin/bash
# =============================================================================
# toolbox-kubeconfig.sh — Só necessário se você for usar a "Opção B" (o
# container 'toolbox' do docker-compose) em vez de instalar kubectl/helm
# direto no host (install-k3d.sh).
#
# O k3d roda no HOST e escreve o kubeconfig com "server: https://127.0.0.1:6550".
# De dentro do container toolbox, 127.0.0.1 aponta pro próprio container, não
# pro host — por isso reescrevemos o endereço para host.docker.internal, que
# o Docker Desktop (Windows/Mac) resolve automaticamente, e que no Linux é
# resolvido via a entrada "extra_hosts: host-gateway" do docker-compose.yml.
#
# Rode isso no HOST (não dentro do container), depois de "k3d cluster create":
#   bash setup/toolbox-kubeconfig.sh
# E depois suba/entre no toolbox:
#   docker compose run --rm toolbox bash
# =============================================================================

set -euo pipefail

CLUSTER_NAME="devops-lab"
VOLUME_NAME="devops_kubeconfig"

echo "Gerando kubeconfig com endereço acessível a partir do container toolbox..."

TMP_KUBECONFIG=$(mktemp)
k3d kubeconfig get "${CLUSTER_NAME}" > "${TMP_KUBECONFIG}"
sed -i 's/127\.0\.0\.1:6550/host.docker.internal:6550/' "${TMP_KUBECONFIG}"

docker volume create "${VOLUME_NAME}" >/dev/null 2>&1 || true
docker run --rm \
  -v "${TMP_KUBECONFIG}:/tmp/config" \
  -v "${VOLUME_NAME}:/root/.kube" \
  alpine sh -c "cp /tmp/config /root/.kube/config"

rm -f "${TMP_KUBECONFIG}"

echo "✅ Pronto. Agora rode: docker compose run --rm toolbox bash"
echo "   E dentro do container: kubectl get nodes"
