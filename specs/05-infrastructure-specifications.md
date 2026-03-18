# Spec 05 — Infrastructure Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

BIN's infrastructure is designed for three goals:

1. **Zero-cost to start** — all components have free or near-free tiers adequate for a barangay-scale pilot
2. **Reproducible environments** — Docker containerization ensures dev, staging, and production behave identically
3. **Horizontal scalability** — adding barangays or users requires adding data and infrastructure, not rewriting code

---

## 2. Deployment Architecture

```
┌────────────────────────────────────────────────────────┐
│  GitHub (Source of Truth)                              │
│  ├── main branch → Production deployment               │
│  └── develop branch → Staging deployment               │
└───────────────┬────────────────────────────────────────┘
                │ GitHub Actions CI/CD
        ┌───────▼──────────┐
        │  Railway (PaaS)  │
        │  ├── FastAPI      │  ← Docker container
        │  └── Scheduler    │  ← Background jobs (same container or separate)
        └───────┬──────────┘
                │
        ┌───────▼──────────────────────────────────────┐
        │  Supabase                                    │
        │  ├── PostgreSQL + PostGIS (primary DB)        │
        │  ├── Supabase Auth                            │
        │  ├── Supabase Storage (photo CDN)             │
        │  └── Supabase Realtime                        │
        └──────────────────────────────────────────────┘

        External services:
        ├── Semaphore SMS API (OTP + resident notifications)
        ├── Firebase Cloud Messaging (push notifications)
        └── PAGASA API (rainfall forecast data)
```

---

## 3. Hosting — Backend (Railway)

| Property | Value |
|---------|-------|
| Platform | Railway |
| Runtime | Docker container |
| Language | Python 3.11 |
| Web server | Uvicorn (ASGI) |
| Process manager | Uvicorn with workers |

**Why Railway:**
- Git-based deploys directly from GitHub
- Docker-native
- Free tier adequate for pilot scale
- Simple horizontal scaling (add instances behind a load balancer)
- Environment variable management built-in

**Deployment trigger:**
- Push to `main` → deploys to production
- Push to `develop` → deploys to staging

**Environment variables (minimum required):**

```
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_JWT_SECRET=
SEMAPHORE_API_KEY=
SEMAPHORE_SENDER_NAME=
FIREBASE_SERVICE_ACCOUNT_JSON=
PAGASA_API_KEY=
ENVIRONMENT=production
LOG_LEVEL=info
```

---

## 4. Containerization (Docker)

All backend environments use an identical Docker image. This eliminates "works on my machine" deployment inconsistencies.

**`Dockerfile` (production):**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

**`docker-compose.yml` (local development):**
```yaml
version: "3.9"
services:
  api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
      - SUPABASE_JWT_SECRET=${SUPABASE_JWT_SECRET}
      - SEMAPHORE_API_KEY=${SEMAPHORE_API_KEY}
      - FIREBASE_SERVICE_ACCOUNT_JSON=${FIREBASE_SERVICE_ACCOUNT_JSON}
      - ENVIRONMENT=development
    volumes:
      - ./backend:/app
    command: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Any new team member can clone the repository and run `docker-compose up` to have the full backend running locally in minutes.

---

## 5. Database (Supabase)

| Property | Value |
|---------|-------|
| Platform | Supabase (managed PostgreSQL) |
| Extensions | PostGIS (spatial queries), pgcrypto (UUID generation) |
| Realtime | Enabled on `reports`, `hotspots`, `flood_risk_alerts` |
| Auth | Supabase Auth (built-in) |
| Storage | Supabase Storage with CDN (report photos) |
| Backups | Supabase automatic daily backups (pro tier) |

**Local development:**  
Supabase CLI supports running a local Supabase instance. Developers can run the full stack (FastAPI + local Supabase) without touching the production database:

```bash
supabase start      # starts local Supabase
supabase db reset   # applies migrations from scratch
supabase stop
```

**Migrations:**  
All schema changes are tracked as versioned SQL migration files in `infra/migrations/`. Applied via Supabase CLI or GitHub Actions during deployment.

---

## 6. Frontend (Flutter)

### Mobile (iOS + Android)

| Property | Value |
|---------|-------|
| Build system | Flutter CLI |
| Distribution | App Store (iOS), Google Play (Android) |
| CI builds | GitHub Actions — Flutter build on PR |
| Release signing | Managed via GitHub Actions secrets |

**No backend hosting required** — Flutter mobile app is distributed via app stores. The app connects directly to the Supabase backend and the FastAPI API over HTTPS.

### Web Dashboard

| Property | Value |
|---------|-------|
| Build system | `flutter build web` |
| Hosting | Supabase Storage static hosting OR GitHub Pages (pilot) |
| CDN | Supabase CDN (same as photo storage) |

The Flutter Web build outputs a static site (`build/web/`). It can be served from any static file host. For v1 pilot, GitHub Pages or Supabase Storage static hosting is sufficient.

---

## 7. CI/CD Pipeline (GitHub Actions)

### Backend Pipeline

```
Trigger: Push to main or develop

Steps:
1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Run tests (pytest)
5. Build Docker image
6. Push image to Railway (via Railway CLI or GitHub integration)
7. Run database migrations (Supabase CLI)
8. Health check: GET /health endpoint
```

### Flutter Pipeline

```
Trigger: Push to main or develop; Pull request to main

Steps:
1. Checkout code
2. Set up Flutter
3. flutter pub get
4. flutter analyze
5. flutter test
6. flutter build apk (Android)     — on main only
7. flutter build ios --no-codesign — on main only (CI smoke build)
8. flutter build web               — on main only
```

---

## 8. Scaling Model

**Current (pilot — single barangay):**
- Railway free tier (512MB RAM, shared CPU)
- Supabase free tier (500MB DB, 1GB storage)
- Semaphore SMS pay-as-you-go
- Estimated cost: near zero for pilot scale (<100 active residents)

**Growth (city-scale — 10–50 barangays):**
- Railway Pro: add workers horizontally (no code changes)
- Supabase Pro: more compute, higher connection limits, daily backups
- All data already scoped by `barangay_id` — no schema changes needed
- On-device AI (TFLite) means AI classification cost is $0 regardless of report volume

**Large scale (provincial/national):**
- Migrate Supabase to self-hosted instance on GCP (Supabase self-hosting is supported)
- Add Railway autoscaling rules
- Consider Supabase read replicas for analytics queries
- Keeps all citizen data within Philippine jurisdiction if DICT/DILG partnership is pursued

---

## 9. Environments

| Environment | URL | Database | Purpose |
|------------|-----|---------|---------|
| Local | `localhost:8000` | Local Supabase instance | Development |
| Staging | `staging.api.bin.app` | Staging Supabase project | QA, PR testing |
| Production | `api.bin.app` | Production Supabase project | Live system |

Production and staging never share a database. Staging uses a separate Supabase project.

---

## 10. Dependency Management

**Python (backend):**  
All dependencies pinned in `requirements.txt` with exact versions. Updated via `pip-compile` (pip-tools). No unpinned dependencies in production.

**Dart/Flutter (frontend):**  
All dependencies version-locked in `pubspec.lock`. Committed to version control.

**Key production dependencies:**

```
fastapi==0.111.x
uvicorn[standard]==0.29.x
supabase==2.x
scikit-learn==1.4.x
shapely==2.x
pyproj==3.x
httpx==0.27.x
pydantic==2.x
```

---

## 11. Out of Scope (Infrastructure v1)

- Kubernetes / container orchestration (Railway handles this)
- Multi-region deployment
- Custom domain SSL certificate management (handled by Railway and Supabase)
- CDN configuration beyond Supabase built-in
- Infrastructure-as-code (Terraform) — deferred to post-pilot
