#!/bin/bash
# =============================================================================
# up.sh — Sobe o ambiente inteiro do zero, na ordem certa.
# Rode no HOST, com kubectl/helm/k3d já instalados (bash install-k3d.sh).
# =============================================================================

set -euo pipefail
cd "$(dirname "$0")"

bash setup/00-create-cluster.sh
bash setup/01-cert-manager.sh
bash setup/02-rancher.sh
bash setup/03-argocd.sh
bash setup/04-gitlab.sh

echo ""
echo "================================================================"
echo " Pausa manual necessária"
echo "================================================================"
echo " Antes de continuar:"
echo " 1. Adicione as entradas de setup/hosts.txt no seu /etc/hosts"
echo " 2. Acesse https://gitlab.lab.local e gere um Registration Token"
echo "    (Admin Area → Runners → New instance runner)"
echo " 3. Rode:  bash setup/05-gitlab-runner.sh <TOKEN>"
echo " 4. Rode:  bash setup/06-sonarqube.sh"
echo ""
echo " (up.sh para por aqui de propósito — runner e Sonar dependem de"
echo "  passos manuais no GitLab que não dá pra automatizar sem token)"
