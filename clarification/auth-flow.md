# Clarification: Authentication Flow

**Status:** Resolved  
**Last updated:** v1.0  
**Affects:** Spec 02 (Frontend), Spec 03 (Backend), Spec 06 (Security)

---

## Question

Should residents be required to verify their phone number, or is email + password sufficient? What happens if a resident has neither a stable email nor reliable SMS access?

## Context

The original plan listed both phone OTP and email/password. The tension is:
- Phone OTP is more accessible for residents with low technical literacy and no email
- Email + password is more familiar for tech-savvy users
- Some residents in peri-urban barangays may not have consistent SMS delivery

## Decision

**Both methods are supported. Phone OTP is recommended but not required.**

Rationale:
- Semaphore SMS has strong PH-network coverage (Globe, Smart, DITO) — SMS reliability is sufficient for the target geography
- Forcing phone OTP excludes residents who prefer email; forcing email excludes residents without one
- Supabase Auth natively supports both without custom implementation overhead

**Login with Google (Supabase OAuth) is included as a third option** for residents who prefer it. This was added during design iteration and does not require additional backend work — Supabase Auth handles it.

## Implications

- Profile setup screen (step 4 of registration) is shown to all users regardless of auth method
- Phone number is stored in `profiles.phone_number` only for residents who register via phone OTP; it is null for email-registered residents
- SMS notifications (report status updates) are only sent to residents with a phone number on file
- FCM push notifications are sent to all residents regardless of auth method
- LGU officers: email + password only; no phone OTP for officer accounts

## Open Questions

- **None** — resolved in v1.0

---

## Reference: Auth Flow Diagram

```
Resident opens app
        │
        ▼
   Login screen
   ┌─────┬──────┬──────┐
   │OTP  │Email │Google│
   └──┬──┴──┬───┴──┬───┘
      │     │      │
      ▼     ▼      ▼
  Semaphore Supabase Supabase
  SMS OTP   Auth    OAuth
      │     │      │
      └─────┴──────┘
              │
              ▼
       JWT issued
              │
              ▼
   New user? → Profile setup (Name, Province, City, Barangay)
   Existing? → Home screen
```
