# Initial Plan — BIN

**Date:** Pre-spec  
**Status:** Archived — superseded by specs/01 through 07  
**Note:** This is the raw problem statement and first-pass ideas that started the project. It is preserved as-is for context. Do not treat anything here as a decision — decisions are in `HISTORY.md` and `clarifications/`.

---

## The Problem We're Trying to Solve

Garbage collection in Barangay San Francisco, San Pablo City, Laguna is scheduled every Friday.

It doesn't actually happen every Friday.

Most weeks it gets delayed — sometimes to the following week, sometimes two weeks out, sometimes three. No announcement is made. No text is sent. The truck either comes or it doesn't. Residents find out by checking if their bags are still on the street by Saturday morning.

When the truck doesn't come, the bags pile up. The bins overflow. The sidewalks fill. And because there's nowhere else to put new garbage while waiting for a collection that might be another week away, people start dumping. Vacant lots. Esteros. Roadsides. Not out of laziness — out of desperation. The system failed them first.

This is not a problem unique to Barangay San Francisco. This is happening in barangays across the country, quietly, every week.

The pain is real on both sides:

**Residents:**
- Don't know when the truck is coming
- Have no official way to report illegal dumpsites
- Get no acknowledgment when they do report something informally (calling the barangay hall, posting on Facebook)
- Eventually stop reporting because nothing ever changes
- Live near drainage canals that clog with uncollected garbage every rainy season and flood their streets

**LGU (waste management office):**
- Has no real-time data on where the worst overflow is happening right now
- Gets verbal complaints but can't see patterns across them
- Can't justify additional trucks or budget requests without data
- Doesn't know the dump site is at critical capacity until collection starts slowing down across the whole city
- Makes every decision reactively, on instinct

The result: a system with no feedback loop. Residents suffer visibly. The LGU operates blindly. And the garbage keeps piling up.

---

## First Idea: A Reporting App

The obvious starting point is a reporting app. Residents see garbage, they report it, the LGU sees the report.

This exists in some form already — a Google Form, a Facebook group, an SMS hotline. And it consistently fails.

Why? Because it's a storage and notification tool. It holds the complaint. It notifies someone. It does not understand what the complaint means. It does not connect one complaint to twenty others filed on the same street over the past month. It does not tell the LGU officer that three streets in one barangay are about to flood because the garbage near the drainage canal has been unresolved for two weeks.

A basic reporting tool gets overwhelmed. Staff manually read every submission, categorize it, assign it, look for patterns. At scale, this is impossible. The system quietly collapses back into the same inaction residents already know.

So the first idea is right — a reporting app — but it's not sufficient on its own. The intelligence layer on top is what makes it actually work.

---

## What We Actually Want to Build

A system that:

1. Makes reporting waste as easy as taking a photo — no forms, no categories, no technical knowledge
2. Automatically classifies what's in the photo (waste type, severity) using AI on the phone itself
3. Tags the GPS location automatically
4. Shows reports on a live map that both residents and LGU officers can see
5. Groups nearby reports into hotspots automatically — so the LGU sees "this street has a critical waste problem" not "here are 47 individual complaints"
6. Tells residents when their report was acted on — a push notification and an SMS in Filipino confirming the garbage was collected
7. Alerts both residents and LGU before heavy rain, if there's unresolved garbage near a drainage canal

That last point is the one nobody else is doing. Waste management and flood risk are the same problem in Philippine cities. BIN should treat them that way.

---

## Who Uses This

**Residents** — specifically urban and peri-urban barangay residents who are directly affected by missed collections and illegal dumpsites. Students, working adults, community-active youth. People who want to act but currently have no effective channel.

**LGU Waste Management Officers** — the people at barangay hall or city hall who currently make dispatch decisions based on verbal complaints and gut feel, and who need real citizen-sourced data to do their jobs properly.

The resident experience needs to be dead simple. Open app, take photo, done. Under 60 seconds. No login complexity, no long forms, no need to understand waste categories.

The LGU experience needs to be operational. A live map showing the worst areas right now. A sorted queue of reports. Evidence for budget requests and route redesign.

---

## Early Technology Thinking

At this point we hadn't made firm decisions. These were the first-pass ideas:

- **Mobile:** Flutter — one codebase for Android and iOS makes sense; most residents use Android
- **Web dashboard for LGU:** Also Flutter Web, or maybe React — this was undecided
- **Backend:** FastAPI (Python) — Python is the right choice if we're running scikit-learn on the backend
- **Database:** Supabase — gives us PostgreSQL, Auth, Storage, and Realtime without running separate services
- **On-device AI:** TensorFlow Lite with EfficientNet-Lite — runs on the phone, no server needed for classification
- **Backend AI:** DBSCAN clustering for hotspots; PostGIS for spatial queries
- **SMS:** Needs to be a Philippine provider — Twilio has bad delivery in provincial areas; look at Semaphore
- **Maps:** OpenStreetMap tiles; flutter_map on mobile; decide on web map library later
- **Push notifications:** Firebase Cloud Messaging

The biggest open question at this stage was the AI pipeline. We knew we wanted on-device classification — but the model needs to be fine-tuned on Philippine waste imagery to actually work. Sari-sari store sachets, kakanin packaging, construction debris from informal settlements — a generic global waste model won't catch these reliably.

---

## Open Questions at This Stage

These were unresolved when we started writing specs. Some are answered now — see `HISTORY.md` and `clarifications/`.

1. Should the web dashboard be Flutter Web or React? One codebase is cleaner; React might perform better on the web. Need to decide before starting frontend work.

2. How do we handle residents with no email address? Phone OTP is the answer, but which SMS provider? And what's the fallback if SMS doesn't arrive?

3. What happens when the AI classification is wrong? Does the resident correct it? Does it go to manual review? What confidence threshold triggers review vs. auto-accept?

4. How does DBSCAN actually get triggered — on every new report? On a schedule? Both?

5. What's the PAGASA API situation? Does a public, reliable endpoint exist for rainfall forecast data? This needs to be confirmed before the flood-risk feature is scoped as a hard commitment.

6. Multi-barangay from day one, or single barangay first and expand later? If we build single-barangay first, how painful is the migration?

7. How do LGU officer accounts get created? Self-registration would be a security problem. Admin-created accounts only — but then who is the admin and what does the admin interface look like?

8. What do we do with reports that never get resolved? At what point do they get archived or escalated?

---

## What Success Looks Like

**For a single barangay pilot:**

- Residents in Barangay San Francisco can submit a waste report in under 60 seconds with no technical knowledge
- LGU officers can see a live map of waste hotspots in their area without refreshing the page
- When a report is resolved, the resident who filed it receives a notification in Filipino confirming action was taken
- At least one instance where pattern analytics surfaced a problem (e.g., the 2–3 week collection delay cycle) that the LGU acted on with data instead of instinct

**For the system overall:**

- The feedback loop is closed. Reporting waste feels like it does something.
- The LGU has data they didn't have before, and they're using it.
- Residents trust that their report will be seen, because they've seen it resolved.

---

## What This Is Not

- Not a route optimization system (we don't tell trucks where to go — we give officers the data to decide)
- Not a social network or a complaint forum — there are no comments, no upvotes, no public debate
- Not a replacement for government — BIN makes the existing LGU system work better; it doesn't work around it
- Not a tool for surveillance — GPS is captured only at report submission; no continuous tracking; no identifying data on the public map

---

## Next Step

Write the full system specifications before touching any code.

Start with `specs/01-system-overview.md`. Work through `02` to `07`. Use the open questions above as the first input to `clarifications/`. Resolve every ambiguity in writing before implementation begins.
