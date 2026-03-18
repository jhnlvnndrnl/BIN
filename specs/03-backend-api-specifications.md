# Spec 03 — Backend API Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

The BIN backend is a FastAPI (Python) application that serves as the single API layer connecting both Flutter platforms to the Supabase database. It handles:

- Report submission and management
- AI processing coordination (DBSCAN clustering, flood-risk analytics)
- SMS dispatch via Semaphore
- Push notification dispatch via Firebase Cloud Messaging (FCM)
- PAGASA rainfall forecast integration
- Scheduled analytics jobs

FastAPI is chosen because it is Python-native, meaning the same runtime environment runs both the HTTP API and the scikit-learn/PostGIS analytics pipeline with no language switching overhead.

---

## 2. Base Configuration

| Property | Value |
|---------|-------|
| Framework | FastAPI |
| Language | Python 3.11+ |
| API style | REST (JSON) |
| Auth enforcement | Supabase JWT validation on all protected endpoints |
| Base URL (local) | `http://localhost:8000` |
| Base URL (production) | `https://api.bin.app` *(placeholder)* |
| API versioning | `/api/v1/` prefix on all routes |

---

## 3. Authentication

All protected endpoints require a valid Supabase JWT in the `Authorization` header:

```
Authorization: Bearer <supabase_jwt>
```

The backend validates the JWT against the Supabase project's JWT secret. No session management is handled by FastAPI — auth state is fully delegated to Supabase Auth.

**Role enforcement:**

| Role | Access |
|------|--------|
| `resident` | Can submit reports, view own reports, view public heatmap data |
| `lgu_officer` | All resident access + manage all reports + trigger status updates + export data |
| `admin` *(future)* | Manage officer accounts, jurisdiction configuration |

---

## 4. API Endpoints

### 4.1 Auth

Auth flows (registration, login, OTP) are handled directly by the Supabase Auth SDK on the client. The backend does not expose auth endpoints. The backend only validates the resulting JWT.

**Exception:** OTP delivery via Semaphore SMS is triggered through the backend when Supabase Auth requests it (configured as a custom SMS provider in Supabase).

---

### 4.2 Reports

#### `POST /api/v1/reports`

Submit a new waste report.

**Auth:** Required (resident)

**Request body:**
```json
{
  "photo_url": "string",          // Supabase Storage URL (uploaded before this call)
  "latitude": "float",
  "longitude": "float",
  "waste_type": "string",         // enum: biodegradable | recyclable | hazardous | bulky | mixed
  "severity": "string",           // enum: minor | moderate | severe | critical
  "ai_confidence": "float",       // 0.0 – 1.0
  "ai_flagged_for_review": "boolean",
  "description": "string | null", // optional resident note
  "barangay_id": "uuid"
}
```

**Response `201`:**
```json
{
  "report_id": "uuid",
  "status": "received",
  "created_at": "ISO8601"
}
```

**Side effects:**
- Writes report to Supabase PostgreSQL
- Triggers Supabase Realtime broadcast → LGU dashboard updates instantly
- Enqueues report for DBSCAN re-clustering job
- If `ai_flagged_for_review: true`, marks report for manual LGU triage

---

#### `GET /api/v1/reports`

Fetch reports. Behavior varies by role.

**Auth:** Required

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Filter by barangay (required for LGU officers) |
| `status` | string | Filter: `received`, `in_progress`, `resolved` |
| `severity` | string | Filter: `minor`, `moderate`, `severe`, `critical` |
| `limit` | int | Default 50, max 200 |
| `offset` | int | Pagination |

**Behavior by role:**
- `resident` — returns only reports submitted by the authenticated resident
- `lgu_officer` — returns all reports within their jurisdiction

**Response `200`:**
```json
{
  "reports": [
    {
      "report_id": "uuid",
      "photo_url": "string",
      "latitude": "float",
      "longitude": "float",
      "waste_type": "string",
      "severity": "string",
      "ai_confidence": "float",
      "ai_flagged_for_review": "boolean",
      "description": "string | null",
      "status": "string",
      "hotspot_id": "uuid | null",
      "created_at": "ISO8601",
      "updated_at": "ISO8601",
      "resolved_at": "ISO8601 | null"
    }
  ],
  "total": "int",
  "limit": "int",
  "offset": "int"
}
```

---

#### `GET /api/v1/reports/{report_id}`

Fetch a single report by ID.

**Auth:** Required (resident sees own reports only; LGU officer sees all within jurisdiction)

**Response `200`:** Single report object (same schema as above)

---

#### `PATCH /api/v1/reports/{report_id}/status`

Update report status. LGU officers only.

**Auth:** Required (lgu_officer)

**Request body:**
```json
{
  "status": "string"    // enum: received | in_progress | resolved
}
```

**Response `200`:**
```json
{
  "report_id": "uuid",
  "status": "string",
  "updated_at": "ISO8601"
}
```

**Side effects:**
- Updates report in database
- Triggers FCM push notification to report submitter
- Triggers Semaphore SMS to report submitter (in Filipino)
- If `resolved`: sets `resolved_at` timestamp, removes from active hotspot if applicable

---

### 4.3 Hotspots

#### `GET /api/v1/hotspots`

Fetch current confirmed waste hotspots for a jurisdiction.

**Auth:** Required

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Required |
| `status` | string | `active` (default) or `resolved` |

**Response `200`:**
```json
{
  "hotspots": [
    {
      "hotspot_id": "uuid",
      "center_latitude": "float",
      "center_longitude": "float",
      "radius_meters": "float",
      "report_count": "int",
      "severity_level": "string",   // max severity of member reports
      "status": "string",           // active | resolved
      "first_report_at": "ISO8601",
      "last_report_at": "ISO8601"
    }
  ]
}
```

---

### 4.4 Heatmap

#### `GET /api/v1/heatmap`

Returns aggregated heatmap data for map rendering. Optimized for fast map overlay updates.

**Auth:** Required

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Required |
| `bbox` | string | Bounding box: `minLng,minLat,maxLng,maxLat` |

**Response `200`:**
```json
{
  "zones": [
    {
      "zone_id": "uuid",
      "polygon": "GeoJSON Polygon",
      "heat_level": "string",   // clear | accumulating | critical
      "report_count": "int"
    }
  ]
}
```

---

### 4.5 Flood Risk Alerts

#### `GET /api/v1/alerts/flood-risk`

Returns active flood-risk alerts for a jurisdiction.

**Auth:** Required

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Required |

**Response `200`:**
```json
{
  "alerts": [
    {
      "alert_id": "uuid",
      "location_description": "string",
      "latitude": "float",
      "longitude": "float",
      "unresolved_report_count": "int",
      "nearest_drainage_point_id": "uuid",
      "distance_to_drainage_meters": "float",
      "rainfall_forecast_mm": "float",
      "forecast_window_hours": "int",
      "risk_level": "string",    // moderate | high | critical
      "issued_at": "ISO8601"
    }
  ]
}
```

---

### 4.6 Analytics

#### `GET /api/v1/analytics/trends`

Returns multi-week report trend data per barangay or street.

**Auth:** Required (lgu_officer)

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Required |
| `granularity` | string | `weekly` (default) or `daily` |
| `weeks` | int | Number of weeks to look back (default 8, max 52) |

**Response `200`:**
```json
{
  "series": [
    {
      "period_start": "ISO8601",
      "period_end": "ISO8601",
      "total_reports": "int",
      "resolved_reports": "int",
      "critical_reports": "int",
      "avg_resolution_hours": "float"
    }
  ]
}
```

---

#### `GET /api/v1/analytics/export`

Export compliance report as PDF or CSV.

**Auth:** Required (lgu_officer)

**Query params:**

| Param | Type | Description |
|-------|------|-------------|
| `barangay_id` | uuid | Required |
| `format` | string | `pdf` or `csv` |
| `start_date` | date | ISO8601 date |
| `end_date` | date | ISO8601 date |

**Response `200`:** Binary file download with appropriate `Content-Type` and `Content-Disposition` headers.

---

### 4.7 Jurisdictions

#### `GET /api/v1/jurisdictions`

Returns all jurisdictions (barangays) accessible to the authenticated officer.

**Auth:** Required (lgu_officer)

**Response `200`:**
```json
{
  "jurisdictions": [
    {
      "barangay_id": "uuid",
      "name": "string",
      "city": "string",
      "province": "string",
      "boundary": "GeoJSON Polygon | null"
    }
  ]
}
```

---

## 5. Background Jobs

These run on a scheduled basis, not in response to user requests.

### 5.1 DBSCAN Clustering Job

**Schedule:** Every 15 minutes (configurable)  
**Trigger:** Also runs immediately after any new report is submitted

**Process:**
1. Queries all unresolved reports from the last 30 days grouped by barangay
2. Runs DBSCAN via scikit-learn with PostGIS proximity grouping
3. Identifies new hotspot clusters and updates existing ones
4. Promotes hotspot severity when report count or severity thresholds are crossed
5. Writes updated hotspot records to `hotspots` table
6. Broadcasts hotspot update via Supabase Realtime to LGU dashboard

**Parameters (v1 defaults, configurable per barangay):**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `eps` | 100 meters | Maximum distance between two reports to be considered neighbors |
| `min_samples` | 3 | Minimum reports to form a hotspot cluster |
| `time_window_days` | 30 | Only include reports within this window |

---

### 5.2 Flood-Risk Forecasting Job

**Schedule:** Every 6 hours (configurable)

**Process:**
1. Fetches current PAGASA rainfall forecast data from PAGASA API
2. Queries all unresolved critical/severe reports with GPS coordinates (via PostGIS)
3. Cross-references report locations with drainage infrastructure points (stored in `drainage_points` table)
4. For each report cluster within `drainage_proximity_threshold` (default: 50 meters) of a drainage point:
   - Checks if forecasted rainfall in next 48 hours exceeds `rainfall_threshold_mm` (default: 30mm)
   - If threshold exceeded: creates or updates a `flood_risk_alert` record
5. Dispatches FCM push notifications + Semaphore SMS to:
   - Residents with unresolved reports in the alert zone
   - LGU officer(s) responsible for the jurisdiction

---

### 5.3 Stale Report Cleanup Job

**Schedule:** Daily at 02:00 local time

**Process:**
- Flags reports older than 60 days as `archived` if still `received` or `in_progress`
- Does not delete; preserves for analytics
- Generates a digest notification to LGU officers summarizing unresolved aged reports

---

## 6. External Integrations

### 6.1 Semaphore SMS

- **Use:** OTP delivery during auth, report status change notifications to residents
- **Language:** Filipino for all resident-facing messages
- **Provider:** Semaphore (PH-native, Globe / Smart / DITO coverage)
- **Configuration:** `SEMAPHORE_API_KEY` environment variable
- **Retry policy:** 3 attempts with exponential backoff on delivery failure

### 6.2 Firebase Cloud Messaging (FCM)

- **Use:** Push notifications delivered to resident devices, including when app is closed
- **Configuration:** `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable
- **Token management:** FCM device tokens stored in `user_fcm_tokens` table; rotated on app open

### 6.3 PAGASA Rainfall Forecast API

- **Use:** Flood-risk forecasting job
- **Endpoint:** PAGASA public forecast API *(endpoint to be confirmed during implementation)*
- **Polling frequency:** Every 6 hours
- **Fallback:** If PAGASA API is unavailable, flood-risk job skips the cycle and logs warning; no alert is issued on stale data

---

## 7. Error Responses

All error responses follow a consistent envelope:

```json
{
  "error": {
    "code": "string",       // machine-readable error code
    "message": "string",    // human-readable description
    "details": {}           // optional additional context
  }
}
```

| HTTP Status | Scenario |
|-------------|---------|
| 400 | Invalid request body or params |
| 401 | Missing or invalid JWT |
| 403 | Authenticated but insufficient role |
| 404 | Resource not found |
| 422 | Validation error (FastAPI default) |
| 429 | Rate limit exceeded |
| 500 | Unexpected server error |

---

## 8. Rate Limiting

| Endpoint group | Limit |
|---------------|-------|
| `POST /api/v1/reports` | 10 reports per resident per hour |
| `GET /api/v1/heatmap` | 60 requests per minute per IP |
| All other endpoints | 120 requests per minute per authenticated user |

Rate limits are enforced at the API gateway level (Railway or a reverse proxy). FastAPI returns `429` with a `Retry-After` header on breach.

---

## 9. Out of Scope (Backend v1)

- WebSocket connections (Realtime is handled by Supabase Realtime directly from client)
- GraphQL API
- Resident-to-officer messaging
- Automated route optimization output
- DILG API integration
