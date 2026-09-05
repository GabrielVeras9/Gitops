# =============================================================================
# Dockerfile — imagem "toolbox" com kubectl, helm e argocd-cli
#
# Uso OPCIONAL: se você não quiser instalar kubectl/helm/argocd-cli no host
# (install-k3d.sh), pode rodar os mesmos scripts de dentro deste container.
# O k3d em si continua rodando no HOST (ver README.md — "Opção B"), porque
# é o jeito mais simples e confiável de expor as portas 80/443 sem precisar
# de truques de rede entre containers.
# =============================================================================
FROM debian:bookworm-slim

ARG KUBECTL_VERSION=v1.30.4
ARG HELM_VERSION=v3.15.4
ARG ARGOCD_VERSION=v2.12.3
ARG DOCKER_CLI_VERSION=25.0.5

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git jq gnupg sudo bash \
    && rm -rf /var/lib/apt/lists/*

# kubectl
RUN curl -fsSL -o /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
      | bash -s -- --version "${HELM_VERSION}"

# argocd cli
RUN curl -fsSL -o /usr/local/bin/argocd \
      "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" \
    && chmod +x /usr/local/bin/argocd

# docker cli (cliente apenas — fala com o Docker do HOST via socket montado)
RUN curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz" \
      | tar xz --strip-components=1 -C /usr/local/bin docker/docker

WORKDIR /workspace
COPY setup/ /workspace/setup/

CMD ["bash"]
