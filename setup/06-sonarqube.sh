#!/bin/bash
# =============================================================================
# 06-sonarqube.sh — Instalação do SonarQube Community via Helm
# Acesso: https://sonarqube.lab.local
#
# Nota: os limites de memória aqui já saem maiores que a primeira versão do
# lab (WSL2), porque na prática 2Gi de limite ficou apertado com o
# Elasticsearch embutido do SonarQube rodando junto com CI batendo nele.
# =============================================================================

set -euo pipefail

SONAR_HOSTNAME="sonarqube.lab.local"
SONAR_NAMESPACE="sonarqube"
SONAR_ADMIN_PASSWORD="Sonar@Lab123"   # Altere após o primeiro acesso!

echo "================================================================"
echo " Instalando SonarQube Community"
echo " URL: https://${SONAR_HOSTNAME}"
echo "================================================================"
echo ""
echo " ⚠️  A instalação pode demorar 5-10 minutos."
echo ""

echo "[1/5] Ajustando vm.max_map_count no kernel (requerido pelo Elasticsearch)..."
# No Docker Desktop (Windows/Mac) isso precisa ser ajustado na VM interna do
# Docker Desktop, não no Windows/Mac diretamente. No Linux (Docker Engine
# nativo), ajusta o kernel do próprio host.
if command -v sysctl >/dev/null 2>&1 && [ -w /proc/sys/vm/max_map_count ] 2>/dev/null; then
  sudo sysctl -w vm.max_map_count=524288
  if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
    echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
  else
    sudo sed -i 's/^vm.max_map_count=.*/vm.max_map_count=524288/' /etc/sysctl.conf
  fi
else
  echo "    → Não deu pra ajustar sysctl direto neste host (normal em Docker Desktop)."
  echo "    → No Docker Desktop: Settings → Resources → cole em '.wslconfig' (Windows)"
  echo "      ou rode: docker run --rm --privileged --pid=host justincormack/nsenter1 \\"
  echo "               sysctl -w vm.max_map_count=524288"
fi

echo "[2/5] Configurando repositório Helm do SonarQube..."
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube 2>/dev/null || true
helm repo update

echo "[3/5] Criando namespace ${SONAR_NAMESPACE}..."
kubectl create namespace "${SONAR_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[4/5] Instalando SonarQube Community Edition..."
helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace "${SONAR_NAMESPACE}" \
  --create-namespace \
  --timeout 10m \
  --set community.enabled=true \
  --set account.adminPassword="${SONAR_ADMIN_PASSWORD}" \
  --set account.currentAdminPassword="admin" \
  --set monitoringPasscode="admin" \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set ingress.hosts[0].name="${SONAR_HOSTNAME}" \
  --set ingress.tls[0].secretName=sonarqube-tls \
  --set ingress.tls[0].hosts[0]="${SONAR_HOSTNAME}" \
  --set "ingress.annotations.cert-manager\.io/cluster-issuer=lab-ca-issuer" \
  --set postgresql.enabled=true \
  --set postgresql.primary.persistence.size=5Gi \
  --set persistence.enabled=true \
  --set persistence.size=5Gi \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=1.5Gi \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=3Gi \
  --set initContainers.resources.requests.memory=128Mi \
  --set initContainers.resources.limits.memory=256Mi \
  --wait

echo "[5/5] Aguardando SonarQube ficar pronto..."
kubectl -n "${SONAR_NAMESPACE}" rollout status deploy/sonarqube-sonarqube --timeout=8m 2>/dev/null || \
  echo "(timeout — verifique com: kubectl get pods -n ${SONAR_NAMESPACE})"

echo ""
echo "================================================================"
echo " ✅ SonarQube Community instalado!"
echo "================================================================"
echo ""
echo " Acesse: https://${SONAR_HOSTNAME}"
echo " Usuário: admin"
echo " Senha:   ${SONAR_ADMIN_PASSWORD}"
echo ""
echo " Para o CI/CD usar esse Sonar, configure no GitLab (grupo ou projeto):"
echo "   SONAR_HOST_URL = http://sonarqube-sonarqube.${SONAR_NAMESPACE}.svc.cluster.local:9000"
echo "   SONAR_TOKEN    = gere em My Account → Security → Generate Tokens"
echo ""
echo " Ambiente completo! Veja o README.md para o restante da configuração"
echo " (hosts, variáveis de CI/CD, etc)."
