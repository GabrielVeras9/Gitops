#!/bin/bash
# =============================================================================
# 01-cert-manager.sh — Instalação do cert-manager com ClusterIssuer
# self-signed para TLS local (idêntico ao ambiente antigo — nada muda com k3d)
# =============================================================================

set -euo pipefail

echo "================================================================"
echo " Instalando cert-manager + ClusterIssuer self-signed"
echo "================================================================"

echo "[1/3] Instalando cert-manager..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait

echo "[2/3] Aguardando cert-manager ficar pronto..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=120s

echo "[3/3] Criando ClusterIssuer self-signed..."
kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# CA raiz para emitir certificados de todos os serviços
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: lab-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: lab.local CA
  secretName: lab-ca-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lab-ca-issuer
spec:
  ca:
    secretName: lab-ca-secret
EOF

echo ""
echo "================================================================"
echo " ✅ cert-manager instalado!"
echo "================================================================"
kubectl get clusterissuers
echo ""
echo " Próximo passo: bash setup/02-rancher.sh"
