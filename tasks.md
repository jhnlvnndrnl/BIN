# tasks.md — Implementation Task Map

Maps each spec to concrete implementation work. Work items are organized by phase.

**Status key:** 🔜 Not started · 🔄 In progress · ✅ Done · ❌ Blocked

---

## Phase 0: Project Setup

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 0.1 | Initialize Flutter project (mobile + web targets in single codebase) | 02 | 🔜 |
| 0.2 | Initialize FastAPI project structure | 03 | 🔜 |
| 0.3 | Create Supabase project (production + staging) | 05 | 🔜 |
| 0.4 | Configure Docker + docker-compose for local dev | 05 §4 | 🔜 |
| 0.5 | Set up Railway deployment from GitHub | 05 §3 | 🔜 |
| 0.6 | Configure GitHub Actions CI pipelines (Flutter + FastAPI) | 05 §7 | 🔜 |
| 0.7 | Set up Supabase CLI and initial migration scaffolding | 05 §5 | 🔜 |
| 0.8 | Enable PostGIS extension on Supabase project | 04 §1 | 🔜 |

---

## Phase 1: Database and Auth

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 1.1 | Write migration: enumerations | 04 §3 | 🔜 |
| 1.2 | Write migration: `jurisdictions` table | 04 §4.1 | 🔜 |
| 1.3 | Write migration: `profiles` table + auth trigger | 04 §4.2 | 🔜 |
| 1.4 | Write migration: `reports` table + spatial indexes | 04 §4.3 | 🔜 |
| 1.5 | Write migration: `hotspots` table | 04 §4.4 | 🔜 |
| 1.6 | Write migration: `drainage_points` table | 04 §4.5 | 🔜 |
| 1.7 | Write migration: `flood_risk_alerts` table | 04 §4.6 | 🔜 |
| 1.8 | Write migration: `analytics_snapshots` table | 04 §4.7 | 🔜 |
| 1.9 | Write migration: `notification_log` table | 04 §4.8 | 🔜 |
| 1.10 | Implement all RLS policies | 06 §4 | 🔜 |
| 1.11 | Configure Supabase Auth: phone OTP with Semaphore as custom SMS provider | 06 §2.1 | 🔜 |
| 1.12 | Configure Supabase Auth: JWT custom claim for `role` | 06 §3.1 | 🔜 |
| 1.13 | Configure Supabase Realtime on relevant tables | 04 §6 | 🔜 |
| 1.14 | Configure `report-photos` storage bucket + policies | 04 §7, 06 §4.4 | 🔜 |
| 1.15 | Seed pilot jurisdiction record (Barangay San Francisco) | 04 §9 | 🔜 |
| 1.16 | Seed drainage points for pilot barangay | 04 §4.5 | 🔜 |

---

## Phase 2: FastAPI Backend Core

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 2.1 | FastAPI project structure, middleware, request_id injection | 03 §2 | 🔜 |
| 2.2 | JWT validation middleware (Supabase JWT) | 03 §3, 06 §2.3 | 🔜 |
| 2.3 | Role-based access control decorator/dependency | 03 §3 | 🔜 |
| 2.4 | Structured JSON logging setup | 07 §2 | 🔜 |
| 2.5 | Global exception handler | 07 §5.1 | 🔜 |
| 2.6 | `GET /health` endpoint | 07 §3.1 | 🔜 |
| 2.7 | `POST /api/v1/reports` | 03 §4.2 | 🔜 |
| 2.8 | `GET /api/v1/reports` (with role-based filtering) | 03 §4.2 | 🔜 |
| 2.9 | `GET /api/v1/reports/{report_id}` | 03 §4.2 | 🔜 |
| 2.10 | `PATCH /api/v1/reports/{report_id}/status` | 03 §4.2 | 🔜 |
| 2.11 | `GET /api/v1/hotspots` | 03 §4.3 | 🔜 |
| 2.12 | `GET /api/v1/heatmap` | 03 §4.4 | 🔜 |
| 2.13 | `GET /api/v1/alerts/flood-risk` | 03 §4.5 | 🔜 |
| 2.14 | `GET /api/v1/analytics/trends` | 03 §4.6 | 🔜 |
| 2.15 | `GET /api/v1/analytics/export` (PDF + CSV) | 03 §4.6 | 🔜 |
| 2.16 | `GET /api/v1/jurisdictions` | 03 §4.7 | 🔜 |
| 2.17 | Rate limiting implementation | 03 §8 | 🔜 |
| 2.18 | Semaphore SMS integration (OTP + status notifications) | 03 §6.1 | 🔜 |
| 2.19 | FCM push notification integration | 03 §6.2 | 🔜 |

---

## Phase 3: Background Jobs

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 3.1 | DBSCAN clustering job (scikit-learn + PostGIS) | 03 §5.1 | 🔜 |
| 3.2 | PAGASA API integration | 03 §6.3 | 🔜 |
| 3.3 | Flood-risk forecasting job | 03 §5.2 | 🔜 |
| 3.4 | Stale report cleanup job | 03 §5.3 | 🔜 |
| 3.5 | Analytics snapshot generation job | 04 §4.7 | 🔜 |
| 3.6 | Job scheduler setup (APScheduler or Railway cron) | 05 §3 | 🔜 |

---

## Phase 4: AI (On-Device)

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 4.1 | Source or train base EfficientNet-Lite model | 01 §6 (AI Components) | 🔜 |
| 4.2 | Collect Philippine waste imagery dataset for fine-tuning | 01 §6 | 🔜 |
| 4.3 | Fine-tune model on Philippine waste imagery | 01 §6 | 🔜 |
| 4.4 | Export to TFLite format | 01 §6 | 🔜 |
| 4.5 | Benchmark model accuracy + inference time on mid-range Android | 01 §6 | 🔜 |
| 4.6 | Integrate TFLite model into Flutter app via `tflite_flutter` | 02 §3.2 | 🔜 |
| 4.7 | Implement confidence threshold logic (0.75 / 0.50 tiers) | clarifications/ai-accuracy.md | 🔜 |

---

## Phase 5: Flutter Mobile App

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 5.1 | Supabase Flutter SDK setup + auth state management | 02 §3 | 🔜 |
| 5.2 | Registration flow (Login → OTP → Profile setup) | 02 §3.2 | 🔜 |
| 5.3 | `flutter_secure_storage` for JWT | 06 §2.3 | 🔜 |
| 5.4 | Home screen with `flutter_map` heatmap | 02 §3.2 | 🔜 |
| 5.5 | Heatmap color zones (green/yellow/red) + hotspot overlay | 02 §5 | 🔜 |
| 5.6 | Supabase Realtime subscription for heatmap updates | 04 §6 | 🔜 |
| 5.7 | Report submission flow (camera → TFLite → form → submit) | 02 §3.2 | 🔜 |
| 5.8 | GPS location capture + reverse geocoding | 02 §3.2 | 🔜 |
| 5.9 | Photo upload to Supabase Storage | 04 §7 | 🔜 |
| 5.10 | Offline report queue (SQLite via drift) | 02 §3.4 | 🔜 |
| 5.11 | Auto-submit queued reports on reconnect | 02 §3.4 | 🔜 |
| 5.12 | Track screen (report history + status) | 02 §3.2 | 🔜 |
| 5.13 | FCM push notification integration | 02 §3.3 | 🔜 |
| 5.14 | Filipino localization (flutter intl) | 02 §5 | 🔜 |
| 5.15 | Flood risk alert display | 02 §3.2 (implied) | 🔜 |

---

## Phase 6: Flutter Web Dashboard

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 6.1 | Login screen (email + password) | 02 §4.2 | 🔜 |
| 6.2 | Sidebar navigation layout | 02 §4.1 | 🔜 |
| 6.3 | Dashboard home: full-jurisdiction `flutter_map` heatmap | 02 §4.2 | 🔜 |
| 6.4 | Supabase Realtime subscription for dashboard updates | 04 §6 | 🔜 |
| 6.5 | Report management screen (severity-sorted queue) | 02 §4.2 | 🔜 |
| 6.6 | Report detail panel (photo, AI result, GPS, status control) | 02 §4.2 | 🔜 |
| 6.7 | One-click status update (triggers resident notification) | 02 §4.3 | 🔜 |
| 6.8 | Pattern analytics panel (trend charts) | 02 §4.2 | 🔜 |
| 6.9 | PDF/CSV export | 02 §4.2 | 🔜 |
| 6.10 | Flood risk alert panel | 02 §4.2 | 🔜 |
| 6.11 | Flutter Web build + static hosting setup | 05 §6 | 🔜 |

---

## Phase 7: Testing

| # | Task | Spec ref | Status |
|---|------|---------|--------|
| 7.1 | FastAPI unit tests (Pydantic validation, auth logic) | 03 | 🔜 |
| 7.2 | FastAPI integration tests (report flow end-to-end) | 03 | 🔜 |
| 7.3 | DBSCAN clustering job unit tests | 03 §5.1 | 🔜 |
| 7.4 | Flood-risk job unit tests | 03 §5.2 | 🔜 |
| 7.5 | Flutter widget tests (registration, report submission, track) | 02 | 🔜 |
| 7.6 | RLS policy tests (cross-user data access attempts) | 06 §4 | 🔜 |
| 7.7 | Offline queue test (submit while offline, reconnect) | 02 §3.4 | 🔜 |
| 7.8 | AI confidence threshold behavior tests | clarifications/ai-accuracy.md | 🔜 |
| 7.9 | Load test at pilot scale (100 concurrent residents) | 07 §6 | 🔜 |

---

## Notes

- Phases 1–3 are backend-only and can proceed in parallel with Phase 4 (AI training)
- Phase 5 and 6 depend on Phase 1 (auth + database) and Phase 2 (API)
- Phase 4 is the highest-risk item (model accuracy is uncertain until tested on real Philippine waste data)
- Tasks 4.1–4.5 are AI/ML work that may require a separate Python notebook environment (`ai/mobile/`)
