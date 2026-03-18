# Spec 04 — Data Model Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

BIN uses Supabase (PostgreSQL + PostGIS) as the primary database. The schema is designed for multi-jurisdiction expansion from day one — a new barangay is onboarded by adding records, not by structural schema changes.

PostGIS is used for all spatial operations: proximity queries, DBSCAN clustering input, drainage point cross-referencing, and heatmap zone generation.

---

## 2. Conventions

- All primary keys are UUIDs generated server-side
- All timestamps are stored in UTC (ISO8601)
- Soft deletes where applicable — no hard deletes on user-generated data
- All spatial columns use PostGIS `GEOGRAPHY(POINT, 4326)` or `GEOGRAPHY(POLYGON, 4326)` with SRID 4326 (WGS84)
- Row Level Security (RLS) is enabled on all tables (see Spec 06 — Security)

---

## 3. Enumerations

```sql
CREATE TYPE waste_type AS ENUM (
  'biodegradable',
  'recyclable',
  'hazardous',
  'bulky',
  'mixed'
);

CREATE TYPE severity_level AS ENUM (
  'minor',
  'moderate',
  'severe',
  'critical'
);

CREATE TYPE report_status AS ENUM (
  'received',
  'in_progress',
  'resolved',
  'archived'
);

CREATE TYPE hotspot_status AS ENUM (
  'active',
  'resolved'
);

CREATE TYPE alert_risk_level AS ENUM (
  'moderate',
  'high',
  'critical'
);

CREATE TYPE user_role AS ENUM (
  'resident',
  'lgu_officer',
  'admin'
);
```

---

## 4. Tables

### 4.1 `jurisdictions`

Represents a barangay or LGU jurisdiction. The top-level scoping entity for all other records.

```sql
CREATE TABLE jurisdictions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,                -- e.g., "Barangay San Francisco"
  city            TEXT NOT NULL,                -- e.g., "San Pablo City"
  province        TEXT NOT NULL,                -- e.g., "Laguna"
  boundary        GEOGRAPHY(POLYGON, 4326),     -- optional jurisdiction boundary polygon
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

### 4.2 `profiles`

Extends Supabase Auth `auth.users`. Created automatically via trigger on `auth.users` insert.

```sql
CREATE TABLE profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    TEXT,
  phone_number    TEXT,
  role            user_role NOT NULL DEFAULT 'resident',
  barangay_id     UUID REFERENCES jurisdictions(id),  -- resident's home barangay
  fcm_token       TEXT,                               -- latest FCM device token
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Notes:**
- `barangay_id` is set during resident profile setup (Registration Step 4)
- LGU officers are assigned a `barangay_id` (their jurisdiction) by an admin
- `fcm_token` is updated every time the resident opens the app

---

### 4.3 `reports`

Core entity. One record per resident waste submission.

```sql
CREATE TABLE reports (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by            UUID NOT NULL REFERENCES profiles(id),
  barangay_id             UUID NOT NULL REFERENCES jurisdictions(id),
  
  -- Location
  location                GEOGRAPHY(POINT, 4326) NOT NULL,
  location_address        TEXT,                         -- human-readable address (reverse geocoded)
  
  -- Photo
  photo_url               TEXT NOT NULL,                -- Supabase Storage URL
  
  -- AI Classification
  waste_type              waste_type NOT NULL,
  severity                severity_level NOT NULL,
  ai_confidence           NUMERIC(4, 3) NOT NULL,       -- 0.000 – 1.000
  ai_flagged_for_review   BOOLEAN NOT NULL DEFAULT false,
  
  -- Resident input
  description             TEXT,                         -- optional free text
  
  -- Status
  status                  report_status NOT NULL DEFAULT 'received',
  hotspot_id              UUID REFERENCES hotspots(id), -- null until clustered
  
  -- Timestamps
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at             TIMESTAMPTZ,
  archived_at             TIMESTAMPTZ
);

-- Spatial index for proximity queries
CREATE INDEX reports_location_idx ON reports USING GIST (location);
-- Status + barangay for dashboard queries
CREATE INDEX reports_barangay_status_idx ON reports (barangay_id, status);
-- Submitted by for resident track screen
CREATE INDEX reports_submitted_by_idx ON reports (submitted_by);
```

---

### 4.4 `hotspots`

Represents a confirmed waste hotspot — a DBSCAN cluster of geographically proximate reports.

```sql
CREATE TABLE hotspots (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay_id         UUID NOT NULL REFERENCES jurisdictions(id),
  
  center              GEOGRAPHY(POINT, 4326) NOT NULL,  -- centroid of cluster
  radius_meters       NUMERIC(8, 2) NOT NULL,           -- approximate cluster radius
  
  report_count        INT NOT NULL DEFAULT 0,
  severity_level      severity_level NOT NULL,           -- max severity of member reports
  status              hotspot_status NOT NULL DEFAULT 'active',
  
  first_report_at     TIMESTAMPTZ NOT NULL,
  last_report_at      TIMESTAMPTZ NOT NULL,
  resolved_at         TIMESTAMPTZ,
  
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX hotspots_barangay_status_idx ON hotspots (barangay_id, status);
CREATE INDEX hotspots_center_idx ON hotspots USING GIST (center);
```

---

### 4.5 `drainage_points`

Reference data. Known drainage infrastructure locations used in flood-risk calculations.

```sql
CREATE TABLE drainage_points (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay_id     UUID NOT NULL REFERENCES jurisdictions(id),
  location        GEOGRAPHY(POINT, 4326) NOT NULL,
  description     TEXT,                   -- e.g., "Canal junction at Rizal St."
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX drainage_points_location_idx ON drainage_points USING GIST (location);
```

**Note:** Drainage point data is seeded by the system administrator during initial barangay onboarding. Not user-submitted.

---

### 4.6 `flood_risk_alerts`

Generated by the flood-risk forecasting background job (Spec 03 §5.2).

```sql
CREATE TABLE flood_risk_alerts (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay_id                 UUID NOT NULL REFERENCES jurisdictions(id),
  
  location                    GEOGRAPHY(POINT, 4326) NOT NULL,
  location_description        TEXT,
  
  nearest_drainage_point_id   UUID REFERENCES drainage_points(id),
  distance_to_drainage_meters NUMERIC(8, 2),
  
  unresolved_report_count     INT NOT NULL,
  rainfall_forecast_mm        NUMERIC(6, 2) NOT NULL,
  forecast_window_hours       INT NOT NULL DEFAULT 48,
  risk_level                  alert_risk_level NOT NULL,
  
  notified_residents          UUID[],                 -- array of profile IDs notified
  notified_at                 TIMESTAMPTZ,
  
  is_active                   BOOLEAN NOT NULL DEFAULT true,
  resolved_at                 TIMESTAMPTZ,
  
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX flood_alerts_barangay_active_idx ON flood_risk_alerts (barangay_id, is_active);
```

---

### 4.7 `analytics_snapshots`

Pre-aggregated weekly analytics used to power the LGU dashboard trend charts. Written by a scheduled job to avoid expensive real-time aggregation queries on large datasets.

```sql
CREATE TABLE analytics_snapshots (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  barangay_id             UUID NOT NULL REFERENCES jurisdictions(id),
  
  period_start            DATE NOT NULL,
  period_end              DATE NOT NULL,
  
  total_reports           INT NOT NULL DEFAULT 0,
  resolved_reports        INT NOT NULL DEFAULT 0,
  critical_reports        INT NOT NULL DEFAULT 0,
  avg_resolution_hours    NUMERIC(8, 2),
  
  hotspots_formed         INT NOT NULL DEFAULT 0,
  hotspots_resolved       INT NOT NULL DEFAULT 0,
  
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX analytics_snapshots_barangay_period_idx 
  ON analytics_snapshots (barangay_id, period_start);
```

---

### 4.8 `notification_log`

Audit trail of all outbound notifications (FCM + SMS).

```sql
CREATE TABLE notification_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id      UUID NOT NULL REFERENCES profiles(id),
  report_id       UUID REFERENCES reports(id),
  alert_id        UUID REFERENCES flood_risk_alerts(id),
  
  channel         TEXT NOT NULL,          -- 'fcm' | 'sms'
  message_body    TEXT NOT NULL,
  
  sent_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered       BOOLEAN,                -- null = unknown, true = confirmed, false = failed
  delivery_error  TEXT
);
```

---

## 5. Relationships Diagram

```
jurisdictions
  ├── profiles (barangay_id)
  ├── reports (barangay_id)
  ├── hotspots (barangay_id)
  ├── drainage_points (barangay_id)
  ├── flood_risk_alerts (barangay_id)
  └── analytics_snapshots (barangay_id)

profiles
  └── reports (submitted_by)

reports
  └── hotspots (hotspot_id) — assigned after DBSCAN clustering

hotspots
  ← reports (hotspot_id)

drainage_points
  ← flood_risk_alerts (nearest_drainage_point_id)
```

---

## 6. Supabase Realtime Configuration

The following tables have Realtime enabled for live dashboard updates:

| Table | Event | Consumer |
|-------|-------|---------|
| `reports` | `INSERT` | LGU Web Dashboard — live report feed |
| `hotspots` | `INSERT`, `UPDATE` | LGU Web Dashboard — heatmap overlay |
| `flood_risk_alerts` | `INSERT` | LGU Web Dashboard — alert panel |
| `reports` | `UPDATE` (status only) | Resident Mobile App — track screen status |

Realtime is scoped by `barangay_id` so officers only receive updates for their jurisdiction.

---

## 7. Supabase Storage

| Bucket | Contents | Access |
|--------|---------|--------|
| `report-photos` | Waste report photos uploaded by residents | Private (authenticated); CDN-served by Supabase Storage |

**Upload flow:**
1. Flutter app uploads photo directly to Supabase Storage before calling `POST /api/v1/reports`
2. Returns a `photo_url` to include in the report submission body
3. File path convention: `report-photos/{barangay_id}/{user_id}/{timestamp}.jpg`

---

## 8. Row Level Security Policies

Full RLS policies are defined in Spec 06 — Security. Summary:

| Table | Resident can read | Resident can write | Officer can read | Officer can write |
|-------|------------------|--------------------|-----------------|-------------------|
| `reports` | Own reports only | Insert own; no delete | All in jurisdiction | Update status only |
| `hotspots` | All in own barangay | ❌ | All in jurisdiction | ❌ (system-written) |
| `profiles` | Own profile | Own profile | All in jurisdiction | ❌ |
| `flood_risk_alerts` | Own barangay | ❌ | All in jurisdiction | ❌ (system-written) |
| `drainage_points` | Own barangay | ❌ | All in jurisdiction | ❌ (admin-seeded) |

---

## 9. Multi-Jurisdiction Design

All user-generated data is scoped to a `barangay_id`. Adding a new barangay requires:

1. Insert a record into `jurisdictions`
2. Seed `drainage_points` for that barangay
3. Assign LGU officer accounts to the new `barangay_id`

No schema changes. No new tables. No new deployments.
