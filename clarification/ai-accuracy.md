# Clarification: AI Accuracy and Fallback Behavior

**Status:** Resolved  
**Last updated:** v1.0  
**Affects:** Spec 02 (Frontend), Spec 03 (Backend), Spec 04 (Data Model)

---

## Question

What happens when the on-device AI classification is wrong or uncertain? Who decides the "real" classification? Does a wrong AI label cause bad data to flow into the hotspot clustering system?

## Context

EfficientNet-Lite produces a confidence score alongside its classification. Low confidence could mean:
- The photo is blurry or poorly framed
- The waste type is genuinely ambiguous
- The image is not a waste photo at all (accidental submission)

If wrong classifications feed into DBSCAN clustering, the hotspot map becomes unreliable — which undermines the core value proposition.

## Decision

**Three-tier handling based on confidence score:**

| Confidence | Behavior |
|-----------|---------|
| ≥ 0.75 | Classification accepted automatically. Report submitted as-is. |
| 0.50 – 0.74 | Classification pre-filled in form, but resident is prompted to confirm or correct before submitting. `ai_flagged_for_review: false` (resident confirmed). |
| < 0.50 | Report is submitted with `ai_flagged_for_review: true`. Appears in LGU review queue before being included in heatmap and clustering. |

**Threshold values are configurable per barangay** — they are not hardcoded in the app. This allows tuning based on real-world accuracy observed during the pilot.

## Implications

- `ai_confidence` and `ai_flagged_for_review` are stored on every `reports` record (Spec 04 §4.3)
- The LGU dashboard report queue separates flagged reports from confirmed ones
- DBSCAN clustering (Spec 03 §5.1) excludes `ai_flagged_for_review: true` reports until an officer manually reviews them
- The resident-facing form allows override of AI classification — `waste_type` and `severity` fields are editable before submission
- A resident override resets `ai_flagged_for_review` to `false` (resident has made a manual judgment call)

## Why This Matters for Data Quality

Hotspot clustering depends on accurate waste type and location data. A high false-positive rate for "critical" severity — caused by low-confidence AI over-classification — would erode LGU trust in the dashboard. The manual review gate for low-confidence reports is the data quality control mechanism.

During the pilot, flagged-vs-confirmed report ratios should be monitored as a proxy for model accuracy. If > 20% of reports are flagged for manual review, the model needs retraining on local Philippine waste imagery.

## Open Questions

- **Confidence thresholds (0.75 / 0.50):** These are initial values based on EfficientNet-Lite documentation. They should be revisited after the first 100 real-world reports during the pilot.
- **Model retraining cadence:** Not defined for v1. Deferred to post-pilot based on observed accuracy data.
