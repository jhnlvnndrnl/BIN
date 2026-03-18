# Spec 07 — Observability Specifications

**Project:** BIN — See it. Bin it. Done.  
**Version:** 1.0  
**Status:** Complete

---

## 1. Overview

Observability answers three questions at any point in time:

- **Is the system working?** (Monitoring + Alerts)
- **Why did something go wrong?** (Logging)
- **How is the system being used?** (Analytics)

BIN is a civic system. Downtime or silent failures directly affect residents who submitted waste reports and LGU officers making dispatch decisions. Observability is not optional — it is a requirement for operating the system responsibly.

---

## 2. Logging

### 2.1 Log Philosophy

- All logs are structured JSON (machine-parseable)
- Logs flow to stdout in all environments; Railway captures and stores them
- No sensitive data in logs (no phone numbers, no email addresses, no GPS coordinates in log messages — use IDs instead)
- Log levels: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`

### 2.2 Log Format

Every log line is a JSON object:

```json
{
  "timestamp": "2025-01-01T12:00:00Z",
  "level": "INFO",
  "service": "bin-api",
  "environment": "production",
  "request_id": "uuid",
  "user_id": "uuid | null",
  "barangay_id": "uuid | null",
  "event": "report.submitted",
  "message": "Waste report submitted successfully",
  "metadata": {
    "report_id": "uuid",
    "waste_type": "biodegradable",
    "severity": "moderate",
    "ai_flagged": false
  }
}
```

`request_id` is a UUID generated per-request and attached to all log lines within that request lifecycle. This enables tracing a full request path through the logs.

### 2.3 Log Events by Component

**API Layer:**

| Event | Level | Description |
|-------|-------|-------------|
| `request.received` | INFO | Incoming request (method, path, user_id) |
| `request.completed` | INFO | Response sent (status code, duration_ms) |
| `request.error` | ERROR | Unhandled exception during request |
| `auth.jwt_invalid` | WARNING | JWT validation failed |
| `auth.role_denied` | WARNING | Authenticated but insufficient role |
| `rate_limit.exceeded` | WARNING | Rate limit hit |

**Report Flow:**

| Event | Level | Description |
|-------|-------|-------------|
| `report.submitted` | INFO | New report created (report_id, waste_type, severity) |
| `report.status_updated` | INFO | Status change (report_id, old_status, new_status, officer_id) |
| `report.flagged_for_review` | INFO | AI confidence below threshold |
| `notification.fcm_sent` | INFO | FCM push dispatched (profile_id, report_id) |
| `notification.fcm_failed` | ERROR | FCM delivery failure |
| `notification.sms_sent` | INFO | SMS dispatched via Semaphore (profile_id — NOT phone number) |
| `notification.sms_failed` | ERROR | SMS delivery failure (error code from Semaphore) |

**Background Jobs:**

| Event | Level | Description |
|-------|-------|-------------|
| `job.dbscan.started` | INFO | Clustering job started (barangay_id, report_count) |
| `job.dbscan.completed` | INFO | Clustering job completed (hotspots_created, hotspots_updated, duration_ms) |
| `job.dbscan.failed` | ERROR | Clustering job error |
| `job.flood_risk.started` | INFO | Flood risk job started |
| `job.flood_risk.alert_issued` | WARNING | Flood risk alert created (alert_id, barangay_id, risk_level) |
| `job.flood_risk.pagasa_unavailable` | WARNING | PAGASA API unreachable; job skipped |
| `job.flood_risk.completed` | INFO | Job completed (alerts_issued, duration_ms) |
| `job.cleanup.started` | INFO | Stale report cleanup started |
| `job.cleanup.completed` | INFO | Cleanup completed (reports_archived) |

---

## 3. Monitoring

### 3.1 Health Check Endpoint

```
GET /health
```

Returns `200 OK` if the service is running. Railway uses this for health checks and automatic restarts on failure.

**Response `200`:**
```json
{
  "status": "ok",
  "version": "1.0.0",
  "environment": "production",
  "database": "ok",
  "timestamp": "ISO8601"
}
```

**Response `503`** (if database unreachable):
```json
{
  "status": "degraded",
  "database": "unreachable",
  "timestamp": "ISO8601"
}
```

The health check performs a lightweight Supabase ping query (`SELECT 1`) to confirm database connectivity.

---

### 3.2 Key Metrics to Track

These are the metrics that matter for operating BIN responsibly. They can be derived from structured logs or from a lightweight metrics layer.

**System Health:**

| Metric | Warning Threshold | Critical Threshold |
|--------|------------------|--------------------|
| API response time (p95) | > 1 second | > 3 seconds |
| API error rate | > 1% of requests | > 5% of requests |
| DBSCAN job failure rate | Any failure | 3 consecutive failures |
| Flood risk job failure rate | Any failure | 3 consecutive failures |
| SMS delivery failure rate | > 5% | > 20% |
| FCM delivery failure rate | > 5% | > 20% |

**Operational:**

| Metric | Description |
|--------|-------------|
| Reports per hour (by barangay) | Volume monitoring; spike detection |
| Reports flagged for manual review | LGU workload proxy |
| Hotspots created per day | System effectiveness signal |
| Average report-to-resolution time | Core SLA metric for LGU accountability |
| Active flood risk alerts | Critical safety metric |

---

### 3.3 Alerting

**v1 approach:** Railway provides basic service monitoring (uptime, crash alerts). Structured logs on Railway are searchable.

**Recommended upgrade (post-pilot):** Integrate with a free-tier observability service (e.g., BetterStack, Grafana Cloud, or Sentry) for:
- Log aggregation and search
- Alert rules on log event patterns
- Uptime monitoring with SMS/email alerting

**Minimum alerts to configure before production launch:**

| Trigger | Channel | Priority |
|---------|---------|---------|
| Health check fails | Email + SMS to on-call | P0 |
| API error rate > 5% in 5 minutes | Email | P1 |
| DBSCAN job fails 3 consecutive times | Email | P1 |
| Flood risk alert issued | Push to officer dashboard (existing feature) | P0 |
| SMS delivery failure rate > 20% | Email | P1 |

---

## 4. Analytics Dashboard (LGU-Facing)

The analytics visible to LGU officers in the web dashboard (described in Spec 02 §4.2) are themselves a form of operational observability — they surface how well the waste management system is working.

Key metrics displayed to officers:

| Metric | Update Frequency | Source |
|--------|-----------------|--------|
| Total active reports | Real-time (Supabase Realtime) | `reports` table |
| Reports by severity | Real-time | `reports` table |
| Active hotspots | Near real-time (15-min DBSCAN cycle) | `hotspots` table |
| Average resolution time (last 30 days) | Daily (analytics snapshot) | `analytics_snapshots` |
| Report volume trend (weekly) | Daily | `analytics_snapshots` |
| Flood risk alerts | Real-time | `flood_risk_alerts` table |

---

## 5. Error Tracking

### 5.1 FastAPI Exception Handling

All unhandled exceptions are caught by a global exception handler, logged at `CRITICAL` level with full stack trace, and returned to the client as a sanitized `500` response (no stack trace in response body).

```python
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.critical(
        "unhandled_exception",
        request_id=request.state.request_id,
        path=request.url.path,
        exc_info=exc
    )
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "internal_error", "message": "An unexpected error occurred."}}
    )
```

### 5.2 Flutter Error Handling

The Flutter apps use `FlutterError.onError` and `runZonedGuarded` to catch and log unhandled exceptions. In v1, these are logged locally. Post-pilot, Sentry's Flutter SDK is recommended for remote error reporting.

---

## 6. Performance Baselines

These are target baselines for a healthy system at pilot scale. Deviations should trigger investigation.

| Operation | Target p95 |
|-----------|-----------|
| `POST /reports` end-to-end | < 800ms |
| `GET /heatmap` | < 400ms |
| `GET /reports` (paginated) | < 300ms |
| Supabase Realtime broadcast (report → dashboard) | < 500ms |
| FCM push delivery | < 5 seconds |
| SMS delivery (Semaphore) | < 30 seconds |
| DBSCAN clustering job (pilot scale, 1 barangay) | < 10 seconds |

---

## 7. Audit Trail

The `notification_log` table (Spec 04 §4.8) serves as a permanent, immutable audit trail of all outbound communications to residents. It is never cleaned up.

Additionally, all report status changes are timestamped on the `reports` record itself (`updated_at`, `resolved_at`). Combined with `notification_log`, this allows reconstruction of the full lifecycle of any report.

This audit trail is particularly important for government accountability — the LGU can demonstrate, with timestamps, that they acted on specific resident reports. This is the data infrastructure for future DILG compliance reporting.

---

## 8. Out of Scope (Observability v1)

- Distributed tracing (OpenTelemetry) — valuable but overkill for pilot scale
- Real-time metrics dashboard for system operators (log-based investigation is sufficient for v1)
- Automated anomaly detection
- Performance profiling in production
- A/B testing instrumentation
