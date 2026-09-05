#!/bin/bash
# =============================================================================
# install-k3d.sh — Instala as ferramentas necessárias no HOST (uma vez só)
#
# Diferente do ambiente antigo (LAB/), aqui NÃO instalamos K3s como serviço
# do sistema, NÃO precisamos de WSL2 configurado manualmente, e NÃO editamos
# CoreDNS/hosts do sistema operacional na mão. As únicas ferramentas nativas
# necessárias são binários estáticos pequenos (poucos MB cada) que apenas
# conversam com o Docker — o cluster inteiro (K3s + Rancher + GitLab + ArgoCD
# + SonarQube) roda 100% dentro de containers Docker, gerenciados pelo k3d.
#
# Pré-requisito: Docker (Desktop no Windows/Mac, ou Docker Engine no Linux)
# já instalado e rodando.
# =============================================================================

set -euo pipefail

echo "================================================================"
echo " Instalando ferramentas do host: k3d, kubectl, helm, argocd-cli"
echo "================================================================"

if ! docker info >/dev/null 2>&1; then
  echo "⚠️  ERRO: Docker não está rodando ou não está acessível."
  echo "   Abra o Docker Desktop (Windows/Mac) ou inicie o Docker Engine (Linux) e tente de novo."
  exit 1
fi

echo "[1/4] Instalando k3d..."
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "[2/4] Instalando kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /tmp/kubectl
sudo mv /tmp/kubectl /usr/local/bin/kubectl

echo "[3/4] Instalando helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[4/4] Instalando argocd-cli..."
curl -fsSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /tmp/argocd
sudo mv /tmp/argocd /usr/local/bin/argocd

echo ""
echo "================================================================"
echo " ✅ Ferramentas instaladas!"
echo "================================================================"
k3d version
kubectl version --client
helm version
argocd version --client 2>/dev/null || true
echo ""
echo " Próximo passo: bash setup/00-create-cluster.sh"
