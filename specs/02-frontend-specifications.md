# Spec 02 — Frontend Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

The BIN frontend is a single Flutter/Dart codebase that compiles to two distinct platform targets:

- **Flutter Mobile** — Native iOS and Android app for residents
- **Flutter Web** — Browser-based dashboard for LGU waste management officers

Both platforms share UI components, business logic, the Supabase SDK, and the `flutter_map` package. No duplicate implementation. No inconsistencies between what residents see on mobile and what officers see on web.

---

## 2. Technology Choices

| Concern | Package / Technology | Reason |
|---------|---------------------|--------|
| Framework | Flutter (Dart) | Single codebase for mobile + web; compiles to native ARM code |
| Maps | flutter_map + OpenStreetMap | Free tile source; same package works on mobile and web |
| Camera | image_picker / camera | Native hardware camera access on iOS + Android |
| On-device AI | tflite_flutter (official TFLite plugin) | Runs EfficientNet-Lite directly on device; no server round-trip |
| Offline storage | drift (SQLite) | Offline report queuing; auto-submit on reconnect |
| Push notifications | firebase_messaging (FCM) | Delivered even when app is closed |
| State management | *(TBD in implementation — Riverpod recommended)* | |
| Localization | Flutter intl (built-in) | Filipino + English |

---

## 3. Resident Mobile App

### 3.1 Navigation

Three-item bottom navigation bar:

| Tab | Icon | Description |
|-----|------|-------------|
| Home | Map icon | Live waste heatmap of the resident's area |
| Report | Green trash bin (center, elevated) | Camera → classify → submit flow |
| Track | List icon | Personal report history |

### 3.2 Screens

#### Registration Flow

**Login Screen**
- Options: Email + Password, Phone OTP (via Semaphore SMS), Login with Google (Supabase OAuth)
- "Create Account" link at bottom

**Register Screen**
- Fields: Email or mobile number, Password, Confirm Password
- On submit: sends OTP to registered contact

**OTP Verification Screen**
- 4-digit code input (individual character boxes)
- Resend option below input
- OTP delivered via Semaphore SMS (phone) or email

**Profile Setup Screen**
- Fields: Name, Province, City, Barangay
- This data personalizes the heatmap view and powers flood-risk household scoping
- CTA: "Create Account"

---

#### Home Screen

- Full-screen `flutter_map` heatmap centered on resident's barangay
- Color-coded ward zones:
  - 🟢 Green — No active reports, or all resolved
  - 🟡 Yellow — Accumulating reports, not yet critical
  - 🔴 Red — Confirmed critical hotspot, escalated for priority dispatch
- Search bar (top right) — navigate to specific locations
- Info button (top left) — explains color legend to new users
- Bottom navigation bar

---

#### Report Submission Flow

**Camera Screen**
- Native device camera opens via `camera` package
- Resident takes photo of waste

**AI Processing (inline, ~2 seconds)**
- TFLite runs EfficientNet-Lite on-device
- Outputs: waste type, severity score, confidence score
- If confidence is below threshold: report is flagged for manual LGU review (resident is not told classification details in this case)

**Report Form Screen**
- Pre-filled: waste type, severity (from AI)
- Auto-detected: GPS coordinates (displayed as human-readable address)
- Optional: short description text field
- Editable: resident can override AI classification if clearly wrong
- Submit button

**Success Screen**
- Trash bin upload icon
- Message: "Trash in Bin! Thanks for throwing in Bin! Your help keeps our community clean."
- CTA: "Back to Home"

**Failed Screen** (connectivity issue)
- Trash bin with X icon
- Message: "Trash failed. Please try again. Your report helps our community."
- Report draft is saved locally via SQLite; auto-resubmitted on reconnect
- CTA: "Back to Home"

---

#### Track Screen

- Chronological list of all resident's submitted reports
- Each entry shows: location name, submission date/time, color-coded status icon
  - 🟢 Green trash bin — Resolved (LGU collected)
  - 🟡 Yellow trash bin — Pending (awaiting LGU action)
  - 🔴 Red trash bin — Failed submission (pending local retry)
- Sort option (top right): filter by status or date
- Notifications: resident receives FCM push + Semaphore SMS in Filipino on each status change

---

### 3.3 Notification Behavior

| Trigger | Push (FCM) | SMS (Semaphore) |
|---------|-----------|-----------------|
| Report received by LGU | ✅ | ✅ |
| Report marked In Progress | ✅ | ✅ |
| Report marked Resolved | ✅ | ✅ |
| Flood-risk alert | ✅ | ✅ |

**Sample resolved SMS (Filipino):**
> "Inyong ulat sa [location] ay natugunan na. Maraming salamat sa inyong pakikilahok sa BIN."

SMS must be delivered even when the resident's phone has no data connection. This is why Semaphore SMS (works on any signal, not just data) is used alongside FCM.

---

### 3.4 Offline Behavior

| Feature | Online | Offline |
|---------|--------|---------|
| Submit report | Live submission | Saved to SQLite; auto-submitted on reconnect |
| View own report history | Live | Cached last-known state |
| View heatmap | Live | Shows cached tiles; no live hotspot updates |
| Receive notifications | FCM | SMS delivery still functions |

---

## 4. LGU Web Dashboard

### 4.1 Layout

- Left sidebar (fixed):
  - BIN logo (top)
  - Navigation: Home, Track
- Main content area: fills remaining screen width

No installation required. Accessible from any modern browser at the barangay hall or city hall.

### 4.2 Screens

#### Login Screen
- Email + Password only (no phone OTP for officer accounts)
- Supabase Auth session persists across browser sessions

---

#### Dashboard Home (Heatmap)

- Full-page `flutter_map` heatmap of the officer's full jurisdiction
- Color-coded ward zones (same color language as mobile, extended):
  - 🟢 Light green — Clear, no active reports
  - 🟡 Orange/yellow — Accumulating, being monitored
  - 🔴 Red — Critical hotspot, immediate dispatch required
- Updates in real time via Supabase Realtime — no page refresh needed
- DBSCAN clustered report pins overlay: each pin represents a confirmed hotspot, not an individual report

---

#### Track / Report Management Screen

- Scrollable list of all incoming reports
- Each entry:
  - Location: formatted as "Brgy X, San Pablo, Laguna"
  - Status: color-coded text — `Accumulating` (orange), `Critical` (red), `Resolved` (green)
  - Time since submission
- Click any entry → detail panel:
  - Resident-submitted photo
  - AI classification result (waste type + severity + confidence)
  - Exact GPS coordinates + map preview
  - Time since submission
  - Current status
  - Status update control (single click → triggers resident FCM + SMS)

---

#### Pattern Analytics Panel

- Multi-week trend charts per barangay and per street
- Surfaces chronic problem areas that generate reports consistently over time
- In pilot context (Barangay San Francisco): reveals the 2–3 week collection delay cycle as a systemic pattern
- Provides quantifiable evidence for budget requests, route redesign, additional truck deployment

---

#### Export

- Weekly compliance reports: PDF or CSV
- Covers: total reports, resolution rate, average resolution time, hotspot locations
- For DILG and DENR filing

---

### 4.3 Report Queue Behavior

- Default sort: AI severity score (descending) — most critical reports surface first regardless of submission time
- Secondary sort option: submission time
- Officer cannot delete reports — only update status (Received → In Progress → Resolved)
- Every status update immediately triggers resident notifications (backend handles this automatically)

---

## 5. Shared UI Conventions

### Color Language

Used consistently across mobile and web:

| Color | Meaning |
|-------|---------|
| Green | Resolved / Clear |
| Yellow / Orange | Pending / Accumulating |
| Red | Critical / Failed |

### Map Component

`flutter_map` + OpenStreetMap is used on both platforms. The same package renders correctly in Flutter mobile (native) and Flutter Web (compiled JS). This ensures consistent map behavior and zero additional cost for map tiles.

### Typography and Localization

- UI language: English (default), Filipino (full support via Flutter intl)
- SMS and push notifications to residents: Filipino
- Officer-facing content: English

---

## 6. Design Constraints

| Constraint | Implication |
|-----------|-------------|
| Target devices are mid-range Android phones | UI must be performant on low-to-mid-end hardware; avoid heavy animations |
| Slow / unstable mobile connections are common | All core flows must degrade gracefully offline; on-device AI removes the need for network calls at classification time |
| Residents may have low technical literacy | Report submission flow must be completable in under 60 seconds with no technical knowledge; minimize text input |
| LGU officers use desktop/laptop browsers | Web dashboard is optimized for larger screens; sidebar navigation pattern |

---

## 7. Out of Scope (Frontend v1)

- Dark mode
- Tablet-optimized layout
- Bisaya localization (deferred to Year 2)
- In-app messaging between resident and LGU officer
- Resident profile editing post-registration
