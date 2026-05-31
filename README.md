# ⭐ Review Service — Microservice Avis Produits

![Node.js](https://img.shields.io/badge/Node.js-18-339933?logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-4.x-000000?logo=express&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-security_scan-1904DA?logo=aqua&logoColor=white)
![Version](https://img.shields.io/badge/version-3.2-blue)

Microservice de gestion des avis produits — partie de l'architecture microservices e-commerce déployée sur **Kubernetes** (Helm) ou **Docker Swarm** (Kong Gateway).

> 💡 **Objectif Portfolio** : Ce service illustre la contrainte d'intégrité métier côté microservice — un utilisateur ne peut laisser qu'un seul avis par produit (contrainte UNIQUE en BD), enforced au niveau applicatif avec une réponse 409 Conflict.

---

## 🗺️ Positionnement dans l'Architecture

```
              Frontend (192.168.56.114)
                      │
                      ▼
┌─────────────────────────────────────────────┐
│  Kubernetes Cluster (192.168.56.111)        │
│  Ingress :30080                             │
│  ├── 🔐 auth-service    :3001               │
│  ├── 📦 product-service :3002               │
│  ├── 🛒 order-service   :3003               │
│  └── ⭐ review-service  :3004  ← Ce service │
└─────────────────────────────────────────────┘
                      │
                      ▼
  MariaDB (192.168.56.115:3306) — ecommerce_db
```

**Rôle de ce service :** Avis et notes produits (1-5 étoiles). Lecture publique, écriture authentifiée. Contrainte : 1 avis maximum par utilisateur par produit.

---

## 📡 Endpoints

| Méthode | Endpoint | Auth | Description |
|---------|----------|:----:|-------------|
| `GET` | `/api/reviews/product/:id` | — | Tous les avis d'un produit |
| `POST` | `/api/reviews` | JWT | Créer un avis (1 max/produit/user) |
| `PUT` | `/api/reviews/:id` | JWT/Admin | Modifier un avis |
| `DELETE` | `/api/reviews/:id` | JWT/Admin | Supprimer un avis |
| `GET` | `/api/reviews` | Admin | Tous les avis (modération) |
| `GET` | `/api/reviews/health` | — | Liveness probe |
| `GET` | `/api/reviews/metrics` | — | Métriques Prometheus |

---

## 🔄 Pipeline CI/CD

```
                        GitLab Push / PR
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Stage 1 — Test                                             │
│  └── test-api.sh : 10-13 tests endpoints API                │
├─────────────────────────────────────────────────────────────┤
│  Stage 2 — Build                                            │
│  └── Docker multi-stage : Node 18 → Node 18 Alpine (~80MB) │
├─────────────────────────────────────────────────────────────┤
│  Stage 3 — Security Scan                                    │
│  ├── security-scan.sh    : Trivy CVE scan                   │
│  └── git-security-scan.sh: Détection secrets dans le code   │
├─────────────────────────────────────────────────────────────┤
│  Stage 4 — Push                                             │
│  ├── Harbor   : harbor.myvbox.com/ecommerce/review-service   │
│  └── DockerHub: yaramahi/review-service:v3.2                │
└─────────────────────────────────────────────────────────────┘
```

<details>
  <summary><code>🦊⚙️ Afficher l'Architecture du Pipeline CI/CD (Gitlab)</code></summary>

![Pipeline CI/CD](https://gitlab.com/yara_portfolio/devops/ecommerce/ecommerce-frontend/-/raw/main/.img/Pipeline-CICD-GitLab.png)

</details>

**Fichiers CI/CD :**
- `.gitlab-ci.yml` — Pipeline GitLab
- `Jenkinsfile-ci` — Pipeline Jenkins (stages: Test → Build → Scan → Push)
- `Jenkins Harbor Guide` — Guide setup Jenkins + Harbor

---

## ⚡ Quick Start

```bash
git clone https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/review-service.git
cd review-service
cp .env.example .env && nano .env

npm install && npm start
# ✅ http://localhost:3004/api/reviews/health
```

---

## ⚙️ Variables d'Environnement

| Variable | Description | Valeur | Requis |
|----------|-------------|--------|--------|
| `PORT` | Port du service | `3004` | ✅ |
| `NODE_ENV` | Environnement | `production` | ❌ |
| `DB_HOST` | IP serveur MariaDB | `192.168.56.115` | ✅ |
| `DB_PORT` | Port MariaDB | `3306` | ✅ |
| `DB_NAME` | Base de données | `ecommerce_db` | ✅ |
| `DB_USER` | Utilisateur BD | `devops_user` | ✅ |
| `DB_PASSWORD` | Mot de passe BD | — | ✅ |
| `JWT_SECRET` | Clé JWT (même que auth-service) | — | ✅ |

---

## 📁 Structure du Projet

```
review-service/
├── src/
│   ├── config/database.js        # Pool de connexions MariaDB
│   ├── middleware/
│   │   ├── authMiddleware.js     # Vérification JWT
│   │   └── metrics.js            # Collecte métriques Prometheus
│   ├── routes/review.js          # CRUD avis + contrainte unicité
│   └── server.js
├── testapi/
│   ├── test-api.sh               # Tests intégration (10-13 tests)
│   ├── data-test-api.sql         # Données de test BD
│   ├── security-scan.sh          # Scan CVE Trivy
│   └── git-security-scan.sh      # Détection secrets
├── Dockerfile
├── Jenkinsfile-ci
├── .gitlab-ci.yml
└── .env.example
```

---

## 🚀 Déploiement

### Docker

```bash
docker build -t review-service:v3.2 .

docker run -d \
  --name review-service \
  -p 3004:3004 \
  -e DB_HOST=192.168.56.115 \
  -e DB_PASSWORD=devops_password \
  -e JWT_SECRET=your_secret_min_32_chars \
  review-service:v3.2
```

### Kubernetes (via Helm Chart)

```bash
helm upgrade ecommerce-microservices . \
  --reuse-values \
  --set services.reviewService.image.tag=v3.2
```

---

## 🧪 Tests

```bash
# Health
curl http://localhost:3004/api/reviews/health

# Avis d'un produit (public)
curl http://localhost:3004/api/reviews/product/1

# Login pour obtenir un token
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"john.doe@example.com","password":"password123"}' \
  | jq -r '.token')

# Créer un avis
curl -X POST http://localhost:3004/api/reviews \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"product_id":3,"rating":5,"comment":"Excellent produit!"}'

# Tentative doublon → 409 Conflict
curl -X POST http://localhost:3004/api/reviews \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"product_id":3,"rating":4,"comment":"Second avis"}' # ← 409

# Suite complète
cd testapi && bash test-api.sh
```

---

## 🔗 Projets Liés

| Composant | Repository |
|-----------|------------|
| 🔐 Auth Service | [auth-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/auth-service) |
| 📦 Product Service | [product-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/product-service) |
| 🛒 Order Service | [order-service](https://gitlab.com/yara_portfolio/devops/ecommerce/microservice/order-service) |
| ⎈ Helm Chart | [k8s-helm-chart](https://gitlab.com/yara_portfolio/devops/ecommerce/devops-tools/k8s-helm-chart) |
| 🗄️ Base de données | [ecommerce-database](https://gitlab.com/yara_portfolio/devops/ecommerce/ecommerce-database) |

---

## 👨‍💻 Auteur

**Yara Mahi Mohamed** — Portfolio DevOps & SRE

*⭐ N'oubliez pas de star ce repo si vous le trouvez utile !*
