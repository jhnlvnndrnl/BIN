# Spec 00 — Project Overview

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Spec Complete, Implementation Pending

---

## 1. Purpose

BIN is an AI-powered waste management and civic reporting platform for barangays in the Philippines. It connects residents directly to their LGU waste management officers through a closed-loop feedback system: residents report waste problems, AI classifies and clusters those reports, and the LGU responds with evidence-based dispatch decisions.

The system is designed to replace the broken, feedback-free environment currently present in barangay-level waste management — where residents submit complaints into a void and LGUs make collection decisions by instinct.

---

## 2. Problem Statement

### Resident Pain Points

- No visibility into garbage collection schedules. Collection in affected barangays is nominally weekly but frequently delayed to every two or three weeks with no communication.
- No accountable reporting channel. Calling the barangay hall often goes ignored. Social media posts produce no trackable outcome.
- No feedback loop. Reports submitted through informal channels are never acknowledged, never updated, and never confirmed as resolved. This creates learned helplessness — residents stop reporting.
- Secondary harm. Overflowing garbage near drainage canals worsens flooding during the rainy season.

### LGU Pain Points

- No real-time data on which streets are critically overflowing.
- No pattern detection. Ten reports on the same street over three weeks appear as ten unrelated complaints without a system to aggregate them.
- No evidence for budget requests or route redesign decisions.
- Reactive operations only. No ability to act on emerging problems before they become crises.

---

## 3. Solution Summary

BIN addresses these pain points through three capabilities working together:

**1. AI-powered reporting** — Residents photograph waste; on-device AI (TensorFlow Lite + EfficientNet-Lite) instantly classifies waste type and severity. GPS auto-tags the location. Submission takes under 60 seconds with no technical knowledge required.

**2. Real-time operational dashboard** — Reports appear on the LGU web dashboard instantly via Supabase Realtime. The dashboard surfaces a live heatmap, AI-clustered hotspots, severity-sorted report queues, and pattern analytics across weeks.

**3. Closed feedback loop** — When an LGU officer resolves a report, every resident who filed on that location receives a push notification and SMS in Filipino confirming action was taken. Reporting feels meaningful for the first time.

---

## 4. System Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   RESIDENT DEVICE                   │
│  Flutter Mobile App                                 │
│  ├── Camera (image_picker)                          │
│  ├── TFLite — EfficientNet-Lite (on-device AI)      │
│  ├── GPS tagging                                    │
│  └── FCM push notifications                         │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS / Supabase Realtime
┌───────────────────▼─────────────────────────────────┐
│                  FASTAPI BACKEND                    │
│  ├── REST API layer                                 │
│  ├── scikit-learn DBSCAN clustering                 │
│  ├── Open-Meteo weather forecast                    │           
│  └── FCM notification dispatch                      │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│                  SUPABASE                           │
│  ├── PostgreSQL + PostGIS (primary database)        │
│  ├── Supabase Auth (Phone OTP + Email/Password)     │
│  ├── Supabase Storage (photo CDN)                   │
│  └── Supabase Realtime (live dashboard updates)     │
└───────────────────┬─────────────────────────────────┘
                    │ Supabase Realtime
┌───────────────────▼─────────────────────────────────┐
│                 LGU OFFICER DEVICE                  │
│  React.js Dashboard                                 │
│  ├── Mapbox heatmap                                 │ 
│  ├── Report management queue                        │
│  ├── Pattern analytics panel                        │
│  └── Export (PDF / CSV)                             │
└─────────────────────────────────────────────────────┘
```

---

## 5. User Roles

### Resident
- Primary user of the Flutter mobile app (iOS + Android)
- Actions: register, submit reports, view community heatmap, track own report history, receive status notifications
- Auth: Phone OTP via Firebase SMS, or email + password

### LGU Waste Management Officer
- Primary user of the Web dashboard
- Actions: view live jurisdiction heatmap, manage and triage incoming reports, update report statuses, access pattern analytics, export compliance reports
- Auth: Email + password via Supabase Auth; elevated permissions pre-assigned by system administrator

### System Administrator *(future)*
- Manages LGU officer accounts and jurisdiction scoping
- Not a user-facing role in v1

---

## 6. Platforms

| User | Platform | Technology |
|------|----------|------------|
| Residents | Mobile app (iOS + Android) | Flutter |
| LGU officers | Web dashboard | React.js |


---

## 7. Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend (Mobile + Web) | Flutter / Dart |
| Backend API | FastAPI (Python) |
| Database | Supabase (PostgreSQL + Realtime) |
| Auth | Firebase Auth (Phone OTP + Email/Password) |
| On-device AI | TensorFlow Lite — EfficientNet-Lite |
| Backend AI | scikit-learn (DBSCAN) |
| Maps | Mapbox |
| Push Notifications | Firebase Cloud Messaging |
| SMS | Firebase Authentication |
| File Storage | Supabase Storage |
| Hosting | Railway + GitHub |

---

## 8. AI Components

### On-Device: Computer Vision (Llava + RAG)

Runs directly on the resident's phone. No server round-trip. Works on slow or unstable mobile connections.

**Input:** Resident photo  
**Outputs:**
- Severity score — `minor` → `critical`
- Confidence score — low confidence auto-flags for manual LGU review

Fine-tuned on Philippine waste imagery (sachets, kakanin packaging, construction debris from informal settlements).

### Backend: Predictive Analytics (scikit-learn)

Runs continuously against the accumulated report database.

**DBSCAN clustering** — groups geographically proximate reports into hotspots. Distinguishes a systemic collection failure from isolated complaints.

**Flood-risk forecasting** — cross-references unresolved waste near drainage infrastructure. Issues pre-emptive alerts to residents and LGU officers before flooding occurs.

---

## 9. Core Features

| # | Feature | Who |
|---|---------|-----|
| 1 | AI-powered waste photo reporting | Resident |
| 2 | Live color-coded waste heatmap | Both |
| 3 | Report status tracking + SMS notifications | Resident |
| 4 | LGU dashboard with pattern analytics | LGU officer |
| 5 | Predictive flood-risk waste alerts | Both |
| 6 | Authentication + user profiles | Both |

---

## 10. Core Principles

**Spec before code.** This repository defines all system behavior before implementation begins. Ambiguity in specifications is resolved deliberately through the clarifications/ process.


**AI as a layer, not a gimmick.** AI is applied where it solves a problem that humans cannot solve at scale — waste classification at submission speed, pattern detection across hundreds of reports, flood-risk correlation across spatial and temporal datasets.

**Feedback loop is the product.** The most important feature is not the reporting form or the heatmap. It is the confirmed resolution notification that arrives on a resident's phone after they report waste. That notification transforms BIN from a complaint box into a civic accountability tool.

**Philippine-specific from the ground up.** SMS via Semaphore (Globe, Smart, DITO coverage). AI model fine-tuned on Philippine waste imagery. UI localized in Filipino. Flood-risk alerts calibrated to PAGASA data. Architecture designed for the infrastructure and connectivity constraints of peri-urban barangays.

---

## 11. Out of Scope (v1)

The following are explicitly deferred to future development horizons:

- IoT smart bin sensor integration
- DENR / DILG open data API
- Multi-language support beyond Filipino and English
- Barangay performance metrics for DILG reporting
- National rollout / multi-LGU administration panel
- Self-hosted Supabase deployment (DICT/DILG partnership)

---

## 12. Key Constraints

| Constraint | Detail |
|-----------|--------|
| Connectivity | Must work on slow/unstable mobile connections. On-device AI and offline report queuing are architectural responses to this constraint. |
| Jurisdiction | v1 is scoped to a single barangay pilot. Database schema must support multi-jurisdiction expansion without structural change. |
| Open source | All technologies must be open-source or have free tiers adequate for a collegiate pilot deployment. |

---

## 13. Repository Structure

```
bin/
├── README.md
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
├── archive/                            # Original plans and superseded decisions
│   └── plans/
│       └── initial-plan.md  
│
├── frontend/                           # Flutter app (mobile) 
└── backend/                           # FastAPI backend   
```

---

## 14. How to Read This Project

**Understand the system** → Read `specs/01` through `specs/07` in order.  
**Understand the thinking** → Read `archive/plans/initial-plan.md`, then `HISTORY.md`, then `clarifications/`.  
**Understand the work ahead** → Read `tasks.md`.

---

## 15. Why Spec-Driven Development

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

## 16. Current Status

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

## 17. Related Specifications

| Spec | File |
|------|------|
| System Overview | `specs/01-system-overview.md` |
| Frontend | `specs/02-frontend-specifications.md` |
| Backend API | `specs/03-backend-api-specifications.md` |
| Data Model | `specs/04-data-model-specifications.md` |
| Infrastructure | `specs/05-infrastructure-specifications.md` |
| Security | `specs/06-security-specifications.md` |
| Observability | `specs/07-observability-specifications.md` |

---

## 18. License

Apache 2.0 (planned)