# BIN — See it. Bin it. Done.

> An AI-powered waste management and civic reporting system for barangays in the Philippines.

---

## The Problem

In Barangay San Francisco, San Pablo City, Laguna — and in barangays across the country — waste management fails not because residents don't care, but because the system has no visibility, no feedback, and no accountability on either side.

**Residents don't know** when trucks are coming, where to report issues, or if their reports are ever seen.  
**LGUs don't know** which areas are critical, where illegal dumps are forming, or how to justify decisions with data.

The result: a feedback-free environment where residents suffer visibly and the LGU operates blindly.

---

## What BIN Does

BIN creates a **closed-loop intelligent feedback system** between residents and their LGU:

```
Resident takes photo
  → AI classifies waste type + severity (on-device, ~2 seconds)
  → GPS auto-tags location
  → Report appears on LGU dashboard in real time
  → AI clusters nearby reports into hotspots
  → LGU dispatches collection
  → Resident receives SMS + push notification: resolved
```

This loop does not exist anywhere in Philippine barangay waste management today.

---

## Platforms

| User | Platform | Technology |
|------|----------|------------|
| Residents | Mobile app (iOS + Android) | Flutter |
| LGU officers | Web dashboard | Flutter Web |

Both run from a **single Dart codebase** — shared components, shared business logic, no duplicate development.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend (Mobile + Web) | Flutter / Dart |
| Backend API | FastAPI (Python) |
| Database | Supabase (PostgreSQL + PostGIS + Realtime) |
| Auth | Supabase Auth (Phone OTP + Email/Password) |
| On-device AI | TensorFlow Lite — EfficientNet-Lite |
| Backend AI | scikit-learn (DBSCAN) + PostGIS |
| Maps | flutter_map + OpenStreetMap |
| Push Notifications | Firebase Cloud Messaging |
| SMS | Semaphore SMS (PH-native: Globe, Smart, DITO) |
| File Storage | Supabase Storage |
| Containerization | Docker |
| Hosting | Railway + GitHub |

---

## Repository Structure

```
bin/
├── README.md
├── HISTORY.md                          # Decision log and evolution of the design
├── tasks.md                            # Implementation task map (specs → code)
│
├── specs/                              # System specifications (read these first)
│   ├── 01-system-overview.md
│   ├── 02-frontend-specifications.md
│   ├── 03-backend-api-specifications.md
│   ├── 04-data-model-specifications.md
│   ├── 05-infrastructure-specifications.md
│   ├── 06-security-specifications.md
│   └── 07-observability-specifications.md
│
├── clarifications/                     # Active design decisions and Q&A
│   ├── auth-flow.md
│   └── ai-accuracy.md
│
├── docs/                               # Supporting documentation
│   └── cost-estimate.md
│
├── archive/                            # Original plans and superseded decisions
│   ├── plans/
│   │   └── initial-plan.md
│   └── previous-clarifications/
│
├── frontend/                           # Flutter app (mobile + web) — future
├── backend/                            # FastAPI backend — future
├── ai/                                 # Model training and inference — future
│   ├── mobile/                         #   TFLite EfficientNet-Lite
│   └── backend/                        #   DBSCAN + PostGIS analytics
├── infra/                              # Docker, deployment scripts
└── .github/
    ├── workflows/
    └── instructions/
```

---

## How to Read This Project

**Understand the system** → Read `specs/01` through `specs/07` in order.  
**Understand the thinking** → Read `archive/plans/initial-plan.md`, then `HISTORY.md`, then `clarifications/`.  
**Understand the work ahead** → Read `tasks.md`.

---

## AI Components

### On-Device: Computer Vision (TensorFlow Lite + EfficientNet-Lite)

Runs directly on the resident's phone. No server round-trip. Works on slow or unstable mobile connections.

**Input:** Resident photo  
**Outputs:**
- Waste type — `biodegradable`, `recyclable`, `hazardous`, `bulky`, `mixed`
- Severity score — `minor` → `critical`
- Confidence score — low confidence auto-flags for manual LGU review

Fine-tuned on Philippine waste imagery (sachets, kakanin packaging, construction debris from informal settlements).

### Backend: Predictive Analytics (scikit-learn + PostGIS)

Runs continuously against the accumulated report database.

**DBSCAN clustering** — groups geographically proximate reports into hotspots. Distinguishes a systemic collection failure from isolated complaints.

**Flood-risk forecasting** — cross-references unresolved waste near drainage infrastructure with PAGASA rainfall forecasts. Issues pre-emptive alerts to residents and LGU officers before flooding occurs.

---

## Core Features

| # | Feature | Who |
|---|---------|-----|
| 1 | AI-powered waste photo reporting | Resident |
| 2 | Live color-coded waste heatmap | Both |
| 3 | Report status tracking + SMS notifications | Resident |
| 4 | LGU dashboard with pattern analytics | LGU officer |
| 5 | Predictive flood-risk waste alerts | Both |
| 6 | Authentication + user profiles | Both |

---

## Why Spec-Driven Development

This project builds a system involving on-device AI, real-time data pipelines, government workflows, and public infrastructure. Jumping straight to code in this context produces systems that are expensive to change, hard to test, and architecturally inconsistent.

The workflow:

1. Define problem (human)
2. Generate specs (AI-assisted)
3. Surface gaps (AI-assisted)
4. Answer with domain knowledge (human)
5. Update specs
6. Repeat until decisions are explicit and testable
7. Implement

Every spec in this repository is the output of that process — not a first draft, but a product of deliberate iteration.

---

## Current Status

| Spec | Status |
|------|--------|
| 01 — System Overview | ✅ Complete |
| 02 — Frontend Specifications | ✅ Complete |
| 03 — Backend API Specifications | ✅ Complete |
| 04 — Data Model Specifications | ✅ Complete |
| 05 — Infrastructure Specifications | ✅ Complete |
| 06 — Security Specifications | ✅ Complete |
| 07 — Observability Specifications | ✅ Complete |
| Implementation | 🔜 Pending |

---

## License

Apache 2.0 (planned)
