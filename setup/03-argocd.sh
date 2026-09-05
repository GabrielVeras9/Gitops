#!/bin/bash
# =============================================================================
# 03-argocd.sh — Instalação do ArgoCD via Helm (idêntico ao ambiente antigo)
# Acesso: https://argocd.lab.local
# =============================================================================

set -euo pipefail

ARGOCD_HOSTNAME="argocd.lab.local"

echo "================================================================"
echo " Instalando ArgoCD"
echo " URL: https://${ARGOCD_HOSTNAME}"
echo "================================================================"

echo "[1/3] Configurando repositório Helm do ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

echo "[2/3] Instalando ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set server.ingress.hostname="${ARGOCD_HOSTNAME}" \
  --set server.ingress.tls=true \
  --set "server.ingress.annotations.cert-manager\.io/cluster-issuer=lab-ca-issuer" \
  --set server.extraArgs[0]="--insecure" \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 5m

echo "[3/3] Aguardando ArgoCD ficar pronto..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=3m

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "================================================================"
echo " ✅ ArgoCD instalado!"
echo "================================================================"
echo ""
echo " Acesse: https://${ARGOCD_HOSTNAME}"
echo " Usuário: admin"
echo " Senha:   ${ARGOCD_PASS}"
echo ""
echo " ⚠️  Guarde essa senha agora — o secret 'argocd-initial-admin-secret'"
echo "    some depois que você trocar a senha pela primeira vez."
echo ""
echo " Próximo passo: bash setup/04-gitlab.sh"
