#!/bin/bash
# =============================================================================
# 04-gitlab.sh — Instalação do GitLab CE via Helm
# Usa chart v9.x com patch local do schema (contorna bug certmanager.install)
# Acesso: https://gitlab.lab.local
# =============================================================================

set -euo pipefail

GITLAB_HOSTNAME="gitlab.lab.local"
GITLAB_REGISTRY="registry.lab.local"
GITLAB_ROOT_PASSWORD="GitLab@Lab123"   # Altere após o primeiro acesso!
CHART_DIR="/tmp/gitlab-chart"

echo "================================================================"
echo " Instalando GitLab CE"
echo " URL:      https://${GITLAB_HOSTNAME}"
echo " Registry: https://${GITLAB_REGISTRY}"
echo "================================================================"
echo ""
echo " ⚠️  ATENÇÃO: A instalação pode demorar 15-20 minutos."
echo ""

echo "[1/6] Configurando repositório Helm do GitLab..."
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update

echo "[2/6] Detectando versão do chart GitLab 9.x (com serviços embutidos)..."
CHART_VERSION=$(helm search repo gitlab/gitlab --versions --output json | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for v in data:
    major = int(v['version'].split('.')[0])
    if major < 10:
        print(v['version'])
        break
" 2>/dev/null || echo "9.10.0")

echo "    → Usando chart versão: ${CHART_VERSION}"

echo "[3/6] Baixando chart e aplicando patch no schema..."
rm -rf "${CHART_DIR}"
mkdir -p "${CHART_DIR}"
helm pull gitlab/gitlab --version "${CHART_VERSION}" --untar -d "${CHART_DIR}"

echo "    → Removendo sub-chart cert-manager bundled do GitLab (já temos o nosso)..."
rm -rf  "${CHART_DIR}/gitlab/charts/cert-manager/templates/"
rm -rf  "${CHART_DIR}/gitlab/charts/cert-manager/crds/"
rm -f   "${CHART_DIR}/gitlab/charts/cert-manager/values.schema.json"
rm -f   "${CHART_DIR}/gitlab/charts/certmanager-issuer/values.schema.json"

echo "[4/6] Criando namespace e secret da senha root..."
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic gitlab-initial-root-password \
  --from-literal=password="${GITLAB_ROOT_PASSWORD}" \
  -n gitlab \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[5/6] Instalando GitLab CE v${CHART_VERSION} (pode demorar ~15 min)..."
helm upgrade --install gitlab "${CHART_DIR}/gitlab" \
  --namespace gitlab \
  --create-namespace \
  --timeout 20m \
  --skip-crds \
  --set global.edition=ce \
  --set global.hosts.domain=lab.local \
  --set global.hosts.https=true \
  --set global.ingress.class=nginx \
  --set global.ingress.configureCertmanager=false \
  --set certmanager.install=false \
  --set nginx-ingress.enabled=false \
  --set nginx.enabled=false \
  --set certmanager-issuer.email=lab@lab.local \
  --set "global.ingress.annotations.cert-manager\.io/cluster-issuer=lab-ca-issuer" \
  --set global.initialRootPassword.secret=gitlab-initial-root-password \
  --set global.initialRootPassword.key=password \
  --set gitlab-runner.install=false \
  --set prometheus.install=false \
  --set grafana.install=false \
  --set postgresql.primary.persistence.size=5Gi \
  --set redis.master.persistence.size=1Gi \
  --set minio.persistence.size=10Gi \
  --set gitlab.sidekiq.resources.requests.memory=256Mi \
  --set gitlab.webservice.resources.requests.memory=512Mi \
  --set gitlab.gitaly.resources.requests.memory=256Mi \
  --wait

echo "[6/6] Aguardando GitLab webservice ficar pronto..."
kubectl -n gitlab rollout status deploy/gitlab-webservice-default --timeout=10m 2>/dev/null || \
  echo "(timeout — verifique com: kubectl get pods -n gitlab)"

echo ""
echo "================================================================"
echo " ✅ GitLab CE instalado!"
echo "================================================================"
echo ""
echo " Acesse: https://${GITLAB_HOSTNAME}"
echo " Usuário: root"
echo " Senha:   ${GITLAB_ROOT_PASSWORD}"
echo ""
echo " Registry de imagens: https://${GITLAB_REGISTRY}"
echo ""
echo " Próximo passo: bash setup/05-gitlab-runner.sh <REGISTRATION_TOKEN>"
echo " (o token fica em: GitLab → Admin Area → Runners → New instance runner)"
