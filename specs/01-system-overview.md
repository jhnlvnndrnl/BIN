# Spec 01 — System Overview

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

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
│                   RESIDENT DEVICE                    │
│  Flutter Mobile App                                  │
│  ├── Camera (image_picker)                           │
│  ├── TFLite — EfficientNet-Lite (on-device AI)       │
│  ├── GPS tagging                                     │
│  ├── SQLite offline queue (drift)                    │
│  └── FCM push notifications                         │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS / Supabase Realtime
┌───────────────────▼─────────────────────────────────┐
│                  FASTAPI BACKEND                     │
│  ├── REST API layer                                  │
│  ├── scikit-learn DBSCAN clustering                  │
│  ├── PostGIS spatial queries                         │
│  ├── PAGASA rainfall forecast integration            │
│  ├── Semaphore SMS dispatch                          │
│  └── FCM notification dispatch                      │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│                  SUPABASE                            │
│  ├── PostgreSQL + PostGIS (primary database)         │
│  ├── Supabase Auth (Phone OTP + Email/Password)      │
│  ├── Supabase Storage (photo CDN)                    │
│  └── Supabase Realtime (live dashboard updates)      │
└───────────────────┬─────────────────────────────────┘
                    │ Supabase Realtime
┌───────────────────▼─────────────────────────────────┐
│                 LGU OFFICER DEVICE                   │
│  Flutter Web Dashboard (browser, no install)         │
│  ├── flutter_map heatmap                             │
│  ├── Report management queue                         │
│  ├── Pattern analytics panel                         │
│  └── Export (PDF / CSV)                              │
└─────────────────────────────────────────────────────┘
```

---

## 5. User Roles

### Resident
- Primary user of the Flutter mobile app (iOS + Android)
- Actions: register, submit reports, view community heatmap, track own report history, receive status notifications
- Auth: Phone OTP via Semaphore SMS, or email + password

### LGU Waste Management Officer
- Primary user of the Flutter Web dashboard
- Actions: view live jurisdiction heatmap, manage and triage incoming reports, update report statuses, access pattern analytics, export compliance reports
- Auth: Email + password via Supabase Auth; elevated permissions pre-assigned by system administrator

### System Administrator *(future)*
- Manages LGU officer accounts and jurisdiction scoping
- Not a user-facing role in v1

---

## 6. Core Principles

**Spec before code.** This repository defines all system behavior before implementation begins. Ambiguity in specifications is resolved deliberately through the clarifications/ process.

**One codebase, two platforms.** The Flutter mobile app and Flutter Web dashboard share a single Dart codebase. No duplicate frontend development, no inconsistencies between platforms.

**AI as a layer, not a gimmick.** AI is applied where it solves a problem that humans cannot solve at scale — waste classification at submission speed, pattern detection across hundreds of reports, flood-risk correlation across spatial and temporal datasets.

**Feedback loop is the product.** The most important feature is not the reporting form or the heatmap. It is the confirmed resolution notification that arrives on a resident's phone after they report waste. That notification transforms BIN from a complaint box into a civic accountability tool.

**Philippine-specific from the ground up.** SMS via Semaphore (Globe, Smart, DITO coverage). AI model fine-tuned on Philippine waste imagery. UI localized in Filipino. Flood-risk alerts calibrated to PAGASA data. Architecture designed for the infrastructure and connectivity constraints of peri-urban barangays.

---

## 7. Out of Scope (v1)

The following are explicitly deferred to future development horizons:

- IoT smart bin sensor integration
- DENR / DILG open data API
- Multi-language support beyond Filipino and English
- Barangay performance metrics for DILG reporting
- National rollout / multi-LGU administration panel
- Self-hosted Supabase deployment (DICT/DILG partnership)

---

## 8. Key Constraints

| Constraint | Detail |
|-----------|--------|
| Connectivity | Must work on slow/unstable mobile connections. On-device AI and offline report queuing are architectural responses to this constraint. |
| Device range | Target devices are mid-range Android phones common in peri-urban PH communities. EfficientNet-Lite is chosen for its performance profile on constrained hardware. |
| Language | All resident-facing SMS notifications must be in Filipino. UI supports Filipino + English. |
| Jurisdiction | v1 is scoped to a single barangay pilot. Database schema must support multi-jurisdiction expansion without structural change. |
| Open source | All technologies must be open-source or have free tiers adequate for a collegiate pilot deployment. |

---

## 9. Related Specifications

| Spec | File |
|------|------|
| Frontend | `specs/02-frontend-specifications.md` |
| Backend API | `specs/03-backend-api-specifications.md` |
| Data Model | `specs/04-data-model-specifications.md` |
| Infrastructure | `specs/05-infrastructure-specifications.md` |
| Security | `specs/06-security-specifications.md` |
| Observability | `specs/07-observability-specifications.md` |
