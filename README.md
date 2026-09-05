# 🐳 DevOps Lab em Container (k3d)

Versão containerizada do ambiente que está em [`../LAB`](../LAB). Mesma stack
(K3s + Rancher + ArgoCD + GitLab CE + GitLab Runner + SonarQube), mesmos
domínios `.lab.local`, mesma senha padrão — só que o cluster Kubernetes
inteiro roda dentro de containers Docker (via [k3d](https://k3d.io)) em vez
de precisar de WSL2 configurado manualmente. Isso resolve dois problemas do
ambiente antigo:

1. **Reprodutibilidade**: montar tudo numa máquina nova vira "instala Docker
   + roda os scripts", em vez de configurar WSL2, `.wslconfig`, CoreDNS e
   `/etc/hosts` na mão.
2. **Portabilidade real**: funciona em qualquer SO com Docker (Windows/Mac
   com Docker Desktop, ou Linux com Docker Engine puro) — não depende mais
   de WSL2 especificamente.

> ⚠️ **O que isso NÃO resolve**: o consumo de RAM/CPU. GitLab CE e
> SonarQube (com Elasticsearch embutido) continuam pesados — containerizar
> muda *onde* e *como* você instala, não *quanto* recurso o software usa.
> Reserve pelo menos **16 GB de RAM** pro Docker (Docker Desktop → Settings
> → Resources) e uns **20 GB de disco** livres.

---

## 📐 Arquitetura

```
Host (Windows / Mac / Linux) — só precisa ter Docker instalado
└── Docker Engine
    └── k3d (K3s rodando como containers Docker)
        ├── ingress-nginx     → Proxy de entrada (portas 80/443 do host)
        ├── cert-manager      → TLS self-signed automático
        ├── cattle-system     → Rancher UI
        ├── argocd            → ArgoCD (GitOps / deploy contínuo)
        ├── gitlab            → GitLab CE (Git + Registry + Runner)
        └── sonarqube         → SonarQube Community (qualidade de código)
```

Diferença chave em relação ao `LAB/`: lá o K3s era um serviço rodando dentro
de uma distro WSL2 completa. Aqui, `k3d cluster create` sobe um container
Docker fazendo o papel de nó do K3s — o cluster inteiro pode ser destruído e
recriado com um comando (`down.sh` / `up.sh`), sem afetar mais nada no seu
sistema.

---

## 🗂️ Estrutura de arquivos

```
Devops/
├── README.md                    ← este arquivo
├── install-k3d.sh                ← instala k3d/kubectl/helm/argocd-cli no HOST (uma vez)
├── Dockerfile                    ← imagem "toolbox" (opcional, ver Opção B)
├── docker-compose.yml            ← sobe o container toolbox (opcional)
├── up.sh                         ← roda os passos 00-04 em sequência
├── down.sh                       ← destroi o cluster inteiro
└── setup/
    ├── 00-create-cluster.sh      ← cria o cluster k3d + NGINX Ingress
    ├── 01-cert-manager.sh
    ├── 02-rancher.sh
    ├── 03-argocd.sh
    ├── 04-gitlab.sh
    ├── 05-gitlab-runner.sh       ← precisa de um token gerado na UI do GitLab
    ├── 06-sonarqube.sh
    ├── hosts.txt                 ← entradas para o /etc/hosts (sempre 127.0.0.1)
    └── toolbox-kubeconfig.sh     ← só usado na Opção B
```

---

## 🚀 Instalação

### Pré-requisito único

Docker instalado e rodando:
- **Windows/Mac**: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Linux**: Docker Engine (`curl -fsSL https://get.docker.com | sh`)

Nada de WSL2, distro Ubuntu, `.wslconfig` ou CoreDNS manual. Se estiver no
Windows, pode rodar os scripts abaixo direto no **Git Bash** ou no **WSL2**
(qualquer shell bash que tenha acesso ao Docker do Windows funciona — o
WSL2 aqui é só "um terminal linux", não faz mais parte da arquitetura do
cluster em si).

### Opção A — Ferramentas no host (recomendado, mais simples)

```bash
cd Devops
bash install-k3d.sh          # instala k3d, kubectl, helm, argocd-cli (binários pequenos)
bash up.sh                   # cria o cluster + instala cert-manager, Rancher, ArgoCD, GitLab
```

O `up.sh` para antes do Runner e do SonarQube de propósito, porque esses dois
passos dependem de você pegar um token na UI do GitLab primeiro:

```bash
# 1. Adicione as linhas de setup/hosts.txt no seu /etc/hosts (ou
#    C:\Windows\System32\drivers\etc\hosts no Windows, como Administrador)

# 2. Acesse https://gitlab.lab.local (usuário root / GitLab@Lab123)
#    Vá em Admin Area → CI/CD → Runners → "New instance runner"
#    Copie o Registration Token gerado

# 3. Instale o runner
bash setup/05-gitlab-runner.sh <REGISTRATION_TOKEN>

# 4. Instale o SonarQube
bash setup/06-sonarqube.sh
```

### Opção B — Tudo em container, sem instalar nada no host além do Docker

O `k3d` em si **precisa continuar rodando no host** (é ele quem expõe as
portas 80/443 pro seu `127.0.0.1` — fazer isso de dentro de outro container
exigiria configuração de rede bem mais frágil entre containers Docker). O
que dá pra containerizar de verdade é o uso de `kubectl`/`helm`/`argocd-cli`:

```bash
cd Devops

# k3d ainda roda no host — instale só ele:
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Cria o cluster (usa k3d do host)
bash setup/00-create-cluster.sh

# Gera um kubeconfig que o container toolbox consegue enxergar
bash setup/toolbox-kubeconfig.sh

# Constrói a imagem toolbox (kubectl + helm + argocd-cli)
docker compose build

# Entra no container e roda o resto dos scripts de lá
docker compose run --rm toolbox bash
# dentro do container:
kubectl get nodes   # deve funcionar
bash setup/01-cert-manager.sh
bash setup/02-rancher.sh
bash setup/03-argocd.sh
bash setup/04-gitlab.sh
# ... etc
```

> Se `kubectl get nodes` não funcionar dentro do toolbox no Linux, confirme
> que `host.docker.internal` resolve (`getent hosts host.docker.internal`
> dentro do container). Se não resolver, edite `docker-compose.yml` e troque
> a estratégia de rede, ou simplesmente use a Opção A — ela é mais robusta
> porque evita esse tipo de problema de rede entre containers.

---

## 🌐 Configurar /etc/hosts

Copie o conteúdo de [`setup/hosts.txt`](setup/hosts.txt) para:

- **Windows**: `C:\Windows\System32\drivers\etc\hosts` (Notepad como Administrador)
- **Linux/Mac**: `/etc/hosts` (`sudo nano /etc/hosts`)

Sempre `127.0.0.1` — não precisa descobrir IP de VM/WSL2 como no ambiente
antigo, porque o k3d publica as portas 80/443 diretamente no host.

---

## 🖥️ Acesso aos serviços

| Serviço | URL | Usuário | Senha inicial |
|---|---|---|---|
| Rancher | https://rancher.lab.local | admin | `Admin@Lab123` |
| ArgoCD | https://argocd.lab.local | admin | (impressa no fim do script 03) |
| GitLab CE | https://gitlab.lab.local | root | `GitLab@Lab123` |
| SonarQube | https://sonarqube.lab.local | admin | `Sonar@Lab123` |

⚠️ Troque as senhas padrão após o primeiro acesso. O certificado TLS é
self-signed — o navegador vai avisar, clique em "Avançado" → "Prosseguir".

---

## 🔧 Configurando o CI/CD (cicd-template) para apontar pra cá

Se você for reusar o [`../cicd-template`](../cicd-template) e o
[`../argocd-gitops`](../argocd-gitops) neste ambiente, configure as
variáveis de CI/CD no **grupo raiz** do GitLab (Settings → CI/CD →
Variables), assim todo projeto/subgrupo herda automaticamente:

| Variável | Valor | Observação |
|---|---|---|
| `CI_USERNAME` | usuário do GitLab dono do token abaixo | não precisa mascarar |
| `CI_PUSH_TOKEN` | Personal Access Token com `read_repository`, `write_repository`, `read_registry`, `write_registry` | **masked**. Sem `write_registry` o Kaniko não empurra a imagem; sem `write_repository` o push pro `argocd-gitops` falha |
| `ARGOCD_PASSWORD` | senha do admin do ArgoCD (script 03) | **masked** |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | conta do Docker Hub | **masked**, usados pelo Kaniko no `build.yaml` |
| `SONAR_HOST_URL` | `http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000` | **use o Service interno do cluster, não a URL do Ingress** — evita erro de certificado TLS não confiável no `sonar-scanner` |
| `SONAR_TOKEN` | gerado em SonarQube → My Account → Security → Generate Tokens | **masked** |

Além disso, no repositório `argocd-gitops`, confirme em **Settings →
Repository → Protected branches** que a role da conta usada em
`CI_USERNAME`/`CI_PUSH_TOKEN` está autorizada a dar push na branch `main`
(campo "Allowed to push and merge"). Sem isso o deploy falha com
`GitLab: You are not allowed to push code to protected branches`, mesmo com
token e escopo corretos.

---

## 🔍 Problemas comuns (e por que acontecem)

| Sintoma | Causa | Fix |
|---|---|---|
| `sonar-scanner`: `certificate_unknown` | Scanner rodando via Java não confia no cert self-signed do Ingress | Use `SONAR_HOST_URL` apontando pro Service interno (`.svc.cluster.local:9000`), não pro Ingress HTTPS |
| Job trava em `ImagePullBackOff` / `403 Forbidden` | Pod do job tentando pull anônimo de imagem privada | Rode `setup/05-gitlab-runner.sh <token> <user> <senha>` passando credenciais de registry, ou troque a imagem do job por uma pública |
| `git push` → `403`/`401` mesmo com token válido | Branch protegida não libera push pra role da conta do token | GitLab → repo → Settings → Repository → Protected branches |
| SonarQube: `503 Service Temporarily Unavailable` | Pod reiniciando (OOM) ou `vm.max_map_count` baixo pro Elasticsearch embutido | `kubectl describe pod -n sonarqube -l app=sonarqube` (procure `OOMKilled`); confirme `sysctl vm.max_map_count` ≥ `524288` |
| Domínio `.lab.local` não resolve **de dentro** de um pod (ex: job do CI clonando `gitlab.lab.local`) | CoreDNS do cluster não conhece esses domínios (isso é independente do `/etc_hosts` do seu SO, que só serve pro navegador) | Já resolvido pelo `setup/05-gitlab-runner.sh` (patch de CoreDNS dinâmico) — se criar outro serviço com domínio `.lab.local`, adicione ele na mesma lista |

---

## 🧹 Destruir e recriar

```bash
bash down.sh          # apaga o cluster inteiro (todos os dados junto)
bash up.sh            # recria do zero
```

Como tudo é container, "resetar o ambiente" vira isso — nada de reinstalar
WSL2 ou limpar configuração de sistema operacional.

---

## 🔄 Diferenças vs. `LAB/` (ambiente antigo, WSL2)

| Aspecto | `LAB/` (WSL2 + k3s nativo) | `Devops/` (k3d) |
|---|---|---|
| Onde roda o cluster | Serviço systemd dentro do WSL2 | Containers Docker (qualquer SO com Docker) |
| Setup de rede | CoreDNS + IP de nó hardcoded, hosts do Windows e do WSL2 separados | Portas publicadas direto em `127.0.0.1`; IP do Ingress descoberto dinamicamente |
| Portar pra outra máquina | Reconfigurar WSL2, `.wslconfig`, reinstalar tudo | Instalar Docker + rodar 2 scripts |
| Resetar o ambiente | Reinstalar serviços um por um | `down.sh` + `up.sh` |
| Consumo de RAM/CPU | Igual | Igual (não muda — ver aviso no topo) |
