#!/bin/bash
# =============================================================================
# 05-gitlab-runner.sh — Instalação do GitLab Runner no cluster k3d
# =============================================================================

set -euo pipefail

TOKEN=$1
REGISTRY_USER=${2:-}
REGISTRY_PASSWORD=${3:-}

if [ -z "$TOKEN" ]; then
  echo "⚠️  ERRO: Você precisa passar o token de registro do runner."
  echo "Uso: bash 05-gitlab-runner.sh <REGISTRATION_TOKEN> [REGISTRY_USER] [REGISTRY_TOKEN]"
  exit 1
fi

# Registry interno do GitLab. REGISTRY_USER/REGISTRY_PASSWORD são opcionais:
# só são necessários se algum job do cicd-template usar uma imagem privada.
REGISTRY_HOST="registry.lab.local"
REGISTRY_SECRET="gitlab-registry-credentials"

echo "================================================================"
echo " Instalando GitLab Runner"
echo "================================================================"

echo "[1/4] Descobrindo o ClusterIP do NGINX Ingress Controller..."
# Diferente do ambiente antigo (WSL2), aqui NÃO existe um IP fixo de nó —
# o k3d recria os containers a cada 'cluster create', então o IP é descoberto
# dinamicamente sempre que este script roda.
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
echo "    → Ingress ClusterIP: ${INGRESS_IP}"

echo "[2/4] Configurando DNS interno do cluster (CoreDNS) para os domínios .lab.local..."
kubectl get configmap coredns -n kube-system -o yaml | \
sed -e "/gitlab.lab.local\|registry.lab.local\|argocd.lab.local\|rancher.lab.local\|sonarqube.lab.local/d" | \
sed "s/hosts \/etc\/coredns\/NodeHosts {/hosts \/etc\/coredns\/NodeHosts {\n          ${INGRESS_IP} gitlab.lab.local registry.lab.local argocd.lab.local rancher.lab.local sonarqube.lab.local/g" | \
kubectl apply -f -

kubectl rollout restart deploy/coredns -n kube-system
kubectl rollout status deploy/coredns -n kube-system --timeout=30s

echo "[3/4] Configurando repositório Helm do GitLab..."
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update

IMAGE_PULL_SECRETS_LINE=""
if [ -n "$REGISTRY_USER" ] && [ -n "$REGISTRY_PASSWORD" ]; then
  echo "    → Criando Secret de credenciais do registry privado..."
  kubectl create secret docker-registry "${REGISTRY_SECRET}" \
    --docker-server="${REGISTRY_HOST}" \
    --docker-username="${REGISTRY_USER}" \
    --docker-password="${REGISTRY_PASSWORD}" \
    --namespace=gitlab \
    --dry-run=client -o yaml | kubectl apply -f -
  IMAGE_PULL_SECRETS_LINE="    image_pull_secrets = [\"${REGISTRY_SECRET}\"]"
else
  echo "    → REGISTRY_USER/REGISTRY_PASSWORD não informados — pulando Secret de registry privado."
fi

echo "[4/4] Instalando GitLab Runner..."
helm upgrade --install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab \
  --set gitlabUrl="https://gitlab.lab.local/" \
  --set runnerRegistrationToken="${TOKEN}" \
  --set certsSecretName="gitlab-runner-certs" \
  --set rbac.create=true \
  --set serviceAccount.create=true \
  --set runners.privileged=true \
  --set runners.config="[[runners]]
  [runners.kubernetes]
    image = \"ubuntu:22.04\"
    privileged = true
    service_account = \"gitlab-runner\"
${IMAGE_PULL_SECRETS_LINE}
  [runners.kubernetes.volumes]
    [[runners.kubernetes.volumes.empty_dir]]
      name = \"docker-certs\"
      mount_path = \"/certs/client\""

echo ""
echo "================================================================"
echo " ✅ GitLab Runner instalado!"
echo "================================================================"
echo "Ele deve aparecer online na tela de Runners do GitLab em alguns minutos."
echo ""
echo " Próximo passo: bash setup/06-sonarqube.sh"
