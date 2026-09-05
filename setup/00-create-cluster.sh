#!/bin/bash
# =============================================================================
# 00-create-cluster.sh — Cria o cluster K3s dentro do Docker (k3d) +
# NGINX Ingress Controller
#
# Substitui, do ambiente antigo: 01-wsl2-config.md + 02-install-k3s.sh
# Não precisa mais de WSL2, .wslconfig, nem instalar K3s como serviço —
# o cluster inteiro é um conjunto de containers Docker gerenciados pelo k3d.
# =============================================================================

set -euo pipefail

CLUSTER_NAME="devops-lab"

echo "================================================================"
echo " Criando cluster k3d '${CLUSTER_NAME}' + NGINX Ingress Controller"
echo "================================================================"

# ------------------------------------------------------------------------------
# Criar o cluster
# --k3s-arg "--disable=traefik" -> desabilita o Traefik embutido do K3s,
#   porque vamos instalar o NGINX Ingress (igual ao ambiente antigo)
# -p 80/443@loadbalancer -> a porta 80/443 do seu HOST vai direto pro
#   load balancer que o k3d cria, que por sua vez encaminha pro NGINX Ingress
# --api-port -> deixa a API do Kubernetes acessível em localhost:6550
# ------------------------------------------------------------------------------
echo "[1/4] Criando cluster k3d (1 server + 1 agent)..."
k3d cluster create "${CLUSTER_NAME}" \
  --servers 1 \
  --agents 1 \
  --api-port 127.0.0.1:6550 \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait

echo "[2/4] Configurando kubeconfig..."
k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-merge-default --kubeconfig-switch-context
kubectl wait --for=condition=ready node --all --timeout=120s

echo "[3/4] Instalando NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait

echo "[4/4] Aguardando Ingress Controller ficar pronto..."
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=120s

echo ""
echo "================================================================"
echo " ✅ Cluster k3d + NGINX Ingress prontos!"
echo "================================================================"
kubectl get nodes
echo ""
kubectl get pods -n ingress-nginx
echo ""
echo " A partir de agora, acessar http://localhost e https://localhost no"
echo " HOST já chega no NGINX Ingress. Falta só apontar os domínios .lab.local"
echo " pro 127.0.0.1 no seu /etc/hosts (ver setup/hosts.txt)."
echo ""
echo " Próximo passo: bash setup/01-cert-manager.sh"
