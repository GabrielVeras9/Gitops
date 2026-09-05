#!/bin/bash
# =============================================================================
# 02-rancher.sh — Instalação do Rancher via Helm (idêntico ao ambiente antigo)
# Acesso: https://rancher.lab.local
# =============================================================================

set -euo pipefail

RANCHER_HOSTNAME="rancher.lab.local"
RANCHER_PASSWORD="Admin@Lab123"   # Altere após o primeiro acesso!

echo "================================================================"
echo " Instalando Rancher"
echo " URL: https://${RANCHER_HOSTNAME}"
echo "================================================================"

echo "[1/3] Configurando repositório Helm do Rancher..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable 2>/dev/null || true
helm repo update

echo "[2/3] Instalando Rancher (pode demorar 3-5 minutos)..."
helm upgrade --install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname="${RANCHER_HOSTNAME}" \
  --set bootstrapPassword="${RANCHER_PASSWORD}" \
  --set ingress.tls.source=secret \
  --set ingress.ingressClassName=nginx \
  --set replicas=1 \
  --set auditLog.level=0 \
  --wait \
  --timeout 10m

echo "[3/3] Criando certificado TLS para Rancher..."
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: rancher-tls
  namespace: cattle-system
spec:
  secretName: tls-rancher-ingress
  issuerRef:
    name: lab-ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - ${RANCHER_HOSTNAME}
EOF

echo ""
echo "================================================================"
echo " ✅ Rancher instalado!"
echo "================================================================"
kubectl -n cattle-system rollout status deploy/rancher --timeout=5m
echo ""
echo " Acesse: https://${RANCHER_HOSTNAME}"
echo " Senha inicial: ${RANCHER_PASSWORD}"
echo ""
echo " Próximo passo: bash setup/03-argocd.sh"
