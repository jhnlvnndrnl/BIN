# Spec 06 — Security Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

BIN handles citizen-submitted photos with GPS coordinates, phone numbers, and barangay-level location data. The security model must protect resident privacy while allowing legitimate LGU officers to access the aggregated data they need to do their jobs.

The security model has three layers:
1. **Authentication** — who are you?
2. **Authorization** — what are you allowed to do?
3. **Data isolation** — what data can you see?

---

## 2. Authentication

### 2.1 Resident Auth

Managed entirely by Supabase Auth. Two methods supported:

**Phone OTP (recommended):**
1. Resident enters phone number
2. Supabase Auth triggers custom SMS provider (FastAPI → Semaphore SMS)
3. Supabase delivers 4-digit OTP via Semaphore to resident's phone
4. Resident enters OTP in app
5. Supabase Auth creates session; issues JWT
6. JWT stored securely in Flutter secure storage (`flutter_secure_storage`)

**Email + Password:**
1. Resident enters email and password
2. Supabase Auth handles registration and login
3. Email confirmation required for new accounts
4. JWT issued on successful login; stored in `flutter_secure_storage`

### 2.2 LGU Officer Auth

Email + password only. No phone OTP.  
Officer accounts are created by a system administrator — officers cannot self-register.

### 2.3 JWT Handling

| Property | Value |
|---------|-------|
| JWT issuer | Supabase Auth |
| JWT validation | FastAPI validates against `SUPABASE_JWT_SECRET` on every request |
| JWT expiry | 1 hour (Supabase default) |
| Refresh | Supabase Auth handles automatic refresh on client |
| Storage (mobile) | `flutter_secure_storage` (iOS Keychain / Android Keystore) |
| Storage (web) | In-memory only; no localStorage; session ends on tab close |

---

## 3. Authorization

### 3.1 Role Model

Roles are stored in the `profiles.role` column. Role is embedded in the JWT via a Supabase Auth Hook (custom claim).

| Role | Value | Description |
|------|-------|-------------|
| Resident | `resident` | Default role for all self-registered users |
| LGU Officer | `lgu_officer` | Assigned by admin; full jurisdiction access |
| Admin | `admin` | System administrator; manages officer accounts (future) |

### 3.2 Endpoint Authorization

| Endpoint | `resident` | `lgu_officer` | `admin` |
|----------|-----------|--------------|--------|
| `POST /reports` | ✅ | ✅ | ✅ |
| `GET /reports` (own) | ✅ | ✅ | ✅ |
| `GET /reports` (all in jurisdiction) | ❌ | ✅ | ✅ |
| `PATCH /reports/{id}/status` | ❌ | ✅ | ✅ |
| `GET /hotspots` | ✅ (own barangay) | ✅ | ✅ |
| `GET /heatmap` | ✅ (own barangay) | ✅ | ✅ |
| `GET /alerts/flood-risk` | ✅ (own barangay) | ✅ | ✅ |
| `GET /analytics/trends` | ❌ | ✅ | ✅ |
| `GET /analytics/export` | ❌ | ✅ | ✅ |
| `GET /jurisdictions` | ❌ | ✅ | ✅ |

---

## 4. Row Level Security (RLS)

RLS is enabled on all tables in Supabase. All queries — including those from the FastAPI backend using the service role key — go through RLS policies when using the anon or user-scoped Supabase client.

**Important:** The FastAPI backend uses the Supabase **service role key** for internal operations (background jobs, status updates, analytics). The service role bypasses RLS by design. The FastAPI application is responsible for enforcing its own authorization logic on top of this.

RLS policies are enforced for **direct client connections** (i.e., if a Flutter app directly queries Supabase, which it does for Realtime and Storage).

### 4.1 `reports` Policies

```sql
-- Residents can only read their own reports
CREATE POLICY "residents_read_own_reports"
  ON reports FOR SELECT
  USING (auth.uid() = submitted_by);

-- Residents can insert their own reports
CREATE POLICY "residents_insert_reports"
  ON reports FOR INSERT
  WITH CHECK (auth.uid() = submitted_by);

-- LGU officers can read all reports in their jurisdiction
CREATE POLICY "officers_read_jurisdiction_reports"
  ON reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'lgu_officer'
        AND profiles.barangay_id = reports.barangay_id
    )
  );

-- No direct DELETE allowed for any role (soft archive only)
```

### 4.2 `profiles` Policies

```sql
-- Users can read and update their own profile
CREATE POLICY "users_manage_own_profile"
  ON profiles FOR ALL
  USING (auth.uid() = id);

-- LGU officers can read profiles of residents in their jurisdiction
CREATE POLICY "officers_read_jurisdiction_profiles"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles officer
      WHERE officer.id = auth.uid()
        AND officer.role = 'lgu_officer'
        AND officer.barangay_id = profiles.barangay_id
    )
  );
```

### 4.3 `hotspots` and `flood_risk_alerts` Policies

```sql
-- All authenticated users can read hotspots in their barangay
CREATE POLICY "authenticated_read_barangay_hotspots"
  ON hotspots FOR SELECT
  USING (
    barangay_id = (
      SELECT barangay_id FROM profiles WHERE id = auth.uid()
    )
  );

-- Only service role (backend) can insert/update
-- No INSERT/UPDATE policy for any user role
```

### 4.4 `report-photos` Storage Policy

```sql
-- Residents can upload to their own folder only
-- Path format: report-photos/{barangay_id}/{user_id}/{timestamp}.jpg
CREATE POLICY "residents_upload_own_photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'report-photos'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- Authenticated users can read photos from their barangay
CREATE POLICY "authenticated_read_barangay_photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'report-photos'
    AND auth.role() = 'authenticated'
  );
```

---

## 5. Privacy

### 5.1 Data Minimization

BIN collects only what is necessary to operate the system:

| Data | Collected | Purpose |
|------|-----------|---------|
| Phone number | Optional (OTP auth path) | Auth only |
| Email | Optional (email auth path) | Auth only |
| Name | Yes | Display in profile; resident communication |
| Barangay | Yes | Scopes heatmap; flood-risk scoping |
| GPS coordinates | Per report | Report location; hotspot clustering |
| Photo | Per report | AI classification; LGU verification |
| Report description | Optional free text | Additional context; resident chooses to share |

BIN does **not** collect:
- Precise home address
- Real-time location tracking (GPS is captured only at report submission moment)
- Device identifiers beyond FCM token
- Any financial information

### 5.2 GPS Data Handling

- GPS coordinates are stored at report-level precision (approximately 10-meter accuracy)
- Coordinates are not rounded or obscured — exact location is necessary for DBSCAN clustering and dispatch routing
- Coordinates are only visible to: the submitting resident (own reports), LGU officers in the same jurisdiction, and the backend analytics system

### 5.3 Photo Storage

- Photos are stored in Supabase Storage (private bucket)
- Photos are not publicly accessible by URL without authentication
- Supabase CDN serves photos with short-lived signed URLs
- Photos are retained indefinitely for analytics and audit purposes (no automatic deletion in v1)

### 5.4 Resident Anonymity on Public Heatmap

The public-facing heatmap (visible to all authenticated users including residents) shows:
- Hotspot locations (clustered; not individual report pins for other users' reports)
- Severity color zones

The heatmap does **not** expose:
- Individual report pins from other residents
- Names or identities of other residents who filed reports
- Exact GPS coordinates of individual reports to other residents

---

## 6. Transport Security

| Connection | Protocol |
|-----------|---------|
| Flutter app → FastAPI | HTTPS (TLS 1.2+) enforced by Railway |
| Flutter app → Supabase | HTTPS (TLS 1.2+) enforced by Supabase |
| FastAPI → Supabase | HTTPS |
| FastAPI → Semaphore SMS | HTTPS |
| FastAPI → FCM | HTTPS |
| FastAPI → PAGASA API | HTTPS |

All production traffic requires HTTPS. HTTP is rejected at the infrastructure level. No mixed content.

---

## 7. API Key and Secret Management

| Secret | Storage |
|--------|---------|
| `SUPABASE_SERVICE_ROLE_KEY` | Railway environment variable (never in code) |
| `SUPABASE_JWT_SECRET` | Railway environment variable |
| `SEMAPHORE_API_KEY` | Railway environment variable |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Railway environment variable (JSON string) |
| `PAGASA_API_KEY` | Railway environment variable |
| Supabase anon key (public) | Flutter app — this is intentionally public; RLS enforces access control |

**Rules:**
- No secrets committed to version control — `.env` files are `.gitignore`d
- GitHub Actions secrets are used for CI/CD pipelines
- Secret rotation procedure: update Railway environment variable; restart service; no code change required

---

## 8. Input Validation and Sanitization

All API request bodies are validated via Pydantic models in FastAPI before any processing occurs.

| Input | Validation |
|-------|-----------|
| `waste_type` | Must be a valid enum value |
| `severity` | Must be a valid enum value |
| `latitude` / `longitude` | Must be valid float within Philippine geographic bounds |
| `ai_confidence` | Must be float 0.0–1.0 |
| `description` | Max 500 characters; stripped of leading/trailing whitespace |
| `photo_url` | Must be a valid Supabase Storage URL from the `report-photos` bucket |
| `barangay_id` | Must be a valid UUID that exists in `jurisdictions` table |

---

## 9. Abuse Prevention

### Report Spam

- Rate limit: 10 reports per resident per hour (enforced at API layer; see Spec 03 §8)
- Duplicate detection: reports from the same user within 50 meters of an existing unresolved report within 10 minutes are flagged for review, not auto-submitted as new reports
- `ai_flagged_for_review: true` reports require manual LGU triage before they appear on the active heatmap

### Account Abuse

- Phone OTP rate limit: 3 OTP requests per phone number per hour (Supabase Auth setting)
- Account lockout: 5 failed login attempts → 15-minute lockout (Supabase Auth default)

---

## 10. Incident Response

*(Procedure to be formalized before production launch)*

**Data breach response:**
1. Immediately revoke affected service role keys
2. Rotate all secrets
3. Notify Supabase support
4. Audit `notification_log` for scope of affected records
5. Notify affected residents if personal data was exposed

**Service outage:**
- FastAPI down: Supabase Realtime and Auth continue to function (residents can still open app and view cached data)
- Supabase down: App enters degraded mode; new reports are queued locally via SQLite
- Semaphore SMS down: FCM push notifications continue; SMS delivery retried with backoff

---

## 11. Out of Scope (Security v1)

- VAPT (Vulnerability Assessment and Penetration Testing) — recommended before any government-partnered deployment
- SOC 2 compliance
- DICT / NPC (National Privacy Commission) formal data protection registration
- End-to-end encryption of report content
- Multi-factor authentication for LGU officers
