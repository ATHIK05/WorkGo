# WorkGo — Product Requirements Document (PRD) v2
**Multi-App Architecture | Backend on Render | SIH 2026 — SIH26089**

**Tagline options:**
- English: *"WorkGo — Trusted Hands, One Tap Away."*
- Hindi: *"WorkGo — भरोसेमंद हाथ, एक टैप में।"*
- Tamil: *"WorkGo — நம்பிக்கையான கைகள், ஒரே தொடுதலில்."*

---

## 0. What Changed From v1

Two structural decisions supersede the previous version:

1. **Backend logic moves off "client-side Firestore workarounds" and onto a real backend hosted on Render.** This replaces the Firebase Cloud Functions role entirely — matching, notifications, payment verification, and demand aggregation are now proper server-side logic, not client heuristics. This is a meaningful upgrade in both security and honesty of the "AI-powered" story.
2. **One app becomes three apps**, split by role exactly the way Rapido splits into the **Rapido** (customer) app and **Rapido Captain** (driver) app — separate binaries, separate app-store listings, separate release cycles, and critically, **each app only ships the code and assets it actually needs**, keeping install size and complexity down instead of one bloated app with role-switching logic and unused screens sitting dead in every user's download.

Everything else from v1 — localization architecture, dark purple/yellow theming, encrypted document storage, proxy-worker calling flow — carries forward unchanged in principle, just re-homed into the correct app and backed by the new Render service where it makes the feature stronger.

---

## 1. Why Three Apps (Not Role-Switching in One App)

| Reason | Explanation |
|---|---|
| **Install size** | A customer never needs worker-verification screens, document-upload/encryption code, or admin analytics bundled into their download — and vice versa. Splitting removes dead weight from each binary. |
| **Store optics** | Judges and real users read "WorkGo" (customer) and "WorkGo Worker" as two purpose-built products, exactly like Rapido / Rapido Captain, Uber / Uber Driver, Swiggy / Swiggy Delivery Partner — it signals a mature, thought-through product rather than a hackathon prototype. |
| **UX focus** | Each app's navigation, onboarding, and default language logic (Req. 1.10) can be tuned precisely for that audience without any shared "if role == worker" branching cluttering the UI layer. |
| **Independent release cadence** | You can ship a Worker-app-only fix without forcing every customer to update, and vice versa — realistic product thinking that also reads well in your SIH pitch. |
| **Security surface** | The Cooperative Admin console — the most sensitive app, holding worker documents and approval powers — is physically a separate codebase/binary from the public customer app, reducing what an attacker gets from reverse-engineering the public APK. |

### The Three Apps

| # | App Name | Users | Primary Platform |
|---|---|---|---|
| 1 | **WorkGo** | Customers (households/institutions booking services) | Android, iOS, Web |
| 2 | **WorkGo Karya** *("Karya" = work/task)* | Workers (smartphone-owning cooperative workers) + Referrers adding Proxy Workers | Android, iOS |
| 3 | **WorkGo Cooperative Console** | Cooperative/Federation Admins and Organizations | Web-first (responsive), Android/iOS companion |

> Naming note: keep "WorkGo" as the umbrella brand across all three app icons/splash screens (consistent brand family, like Rapido's shared visual identity across its two apps), with a clear subtitle/badge distinguishing which app is which on the store listing.

---

## 2. High-Level Architecture

```
┌─────────────┐   ┌──────────────┐   ┌───────────────────────┐
│  WorkGo     │   │  WorkGo      │   │  WorkGo Cooperative   │
│  (Customer) │   │  Karya       │   │  Console (Admin)      │
│  Flutter    │   │  (Worker)    │   │  Flutter Web-first    │
└──────┬──────┘   └──────┬───────┘   └───────────┬───────────┘
       │                 │                       │
       └────────┬────────┴───────────┬───────────┘
                 │  REST/HTTPS calls │
                 ▼                   ▼
        ┌─────────────────────────────────────┐
        │   Backend API — hosted on Render      │
        │   (Node.js + Express, or NestJS)      │
        │   - Matching engine                   │
        │   - Notification orchestration (FCM)  │
        │   - Razorpay webhook + verification   │
        │   - Demand aggregation (cron job)      │
        │   - Document encrypt/decrypt gateway   │
        └───────────────┬────────────────────────┘
                         │  Firebase Admin SDK
                         ▼
        ┌─────────────────────────────────────┐
        │        Firebase (Spark Plan)          │
        │  - Auth (Phone OTP)                   │
        │  - Firestore (single source of truth, │
        │    incl. base64-encrypted documents —  │
        │    no Firebase Storage bucket used)    │
        │  - FCM (push delivery layer)           │
        └─────────────────────────────────────┘
```

**Key principle:** Flutter apps never talk to sensitive logic directly — they call the Render backend over HTTPS, and the backend is the only thing holding Firebase Admin credentials. This is a real client-server split, not client-side workarounds — a genuine upgrade over the Spark-only design.

---

## 3. Shared Code Strategy — Avoiding Duplication Across 3 Apps

Three separate apps must **not** mean three copies of the same theming/localization/networking code maintained by hand. Structure this as a **Flutter monorepo** with one shared internal package.

```
workgo/
 ├── packages/
 │    └── workgo_core/              ← shared Dart package (not a standalone app)
 │         ├── theme/               (dark/light, purple+yellow palette)
 │         ├── localization/        (language pack loader, en/hi/ta assets)
 │         ├── api_client/          (HTTP client wrapper for Render backend)
 │         ├── models/              (User, Worker, Booking, Rating, etc.)
 │         └── widgets/             (shared buttons, cards, form fields, SafeText overflow-safe text widget — see Section 12)
 │
 ├── apps/
 │    ├── workgo_customer/          ← App 1
 │    ├── workgo_karya/             ← App 2
 │    └── workgo_admin_console/     ← App 3
 │
 └── backend/                       ← Render-hosted service (separate repo or subfolder)
      ├── src/
      ├── routes/
      └── services/
```

Each app's `pubspec.yaml` depends on `workgo_core` via a local path dependency. This is the single most important architecture rule in this document — **any agent working on any one app must add shared logic (a new theme color, a new localization key, a new API model) to `workgo_core`, never duplicate it inside an individual app folder.**

---

## 4. Backend on Render — Responsibilities & Endpoints

**Stack:** Node.js + Express (fastest to build and matches Flutter's JSON-first API needs) or NestJS if the team wants stronger structure. Hosted as a Render Web Service, connected to Firebase via a service-account key stored in Render's environment variables (never committed to the repo).

**Render free tier note:** free web services spin down after inactivity, causing a cold-start delay on the first request after idle. For a hackathon demo, either keep a lightweight uptime-ping (e.g., a cron ping every 10 minutes during judging hours) or budget for the smallest paid tier before the finale so the live demo never stalls on a cold start.

### Core Endpoints

| Endpoint | Method | Purpose |
|---|---|---|
| `/api/match-workers` | POST | Given a booking request (service type, location, radius), runs real server-side geo + availability matching against Firestore and returns ranked candidates |
| `/api/bookings/:id/notify` | POST | Triggers FCM push to the relevant worker/customer via Firebase Admin SDK when booking status changes |
| `/api/payments/verify` | POST | Razorpay webhook receiver — verifies payment signature server-side (this was a client-only gap in v1; now done properly) |
| `/api/documents/upload` | POST | Receives a compressed image from the app, encrypts it server-side with a securely managed key, stores the base64 payload in the correct Firestore doc/subcollection |
| `/api/documents/:id` | GET | Decrypts and returns a document for authorized viewers only (Admin console) |
| `/api/insights/demand` | GET | Returns the demand-aggregation results (see Section 7 below) |
| `/api/admin/approve-worker` | POST | Cooperative Admin action — updates verification status, restricted to authenticated admin tokens |

### Scheduled Job: Demand Aggregation
Render supports **Cron Jobs** as a first-class feature — use this to run a nightly aggregation job that reads the last N days of `bookings` from Firestore, computes moving averages and time-of-day/service-type demand patterns per region, and writes the result to `demandStats`. This is a real scheduled backend job now (not a client-side recompute-on-dashboard-load hack from v1) — still an honest **statistical heuristic**, not a trained ML model, but now architected the way a production system actually would be.

---

## 5. App 1 — WorkGo (Customer App)

### Purpose
The public-facing booking app. Optimized for speed-to-book and trust signals.

### Core Screens
1. Splash → Location & Language onboarding (per v1 Section 5.4 rules, unchanged)
2. Phone OTP login
3. Home — category grid (icon-first, 1-word labels)
4. Search/Worker list — cards with photo, rating, distance; **"Book Now"** for app-based workers, **"Call to Book"** for Proxy Workers (dials via `url_launcher`, no in-app record required)
5. Booking flow — slot picker or Emergency toggle
6. Live booking tracker (status pulled via Firestore listener, pushed via Render-triggered FCM)
7. Payment (Razorpay checkout → Render verifies webhook)
8. Invoice/receipt view
9. Rating screen
10. "Add someone I know" — Proxy Worker referral form (customer-side entry point to this flow)
11. Profile & language/theme settings

### What this app does NOT contain
No document-verification UI, no worker-earnings screens, no admin analytics — keeps the binary lean and the UX singularly focused on booking.

---

## 6. App 2 — WorkGo Karya (Worker App)

### Purpose
The "Captain app" equivalent — built for workers to manage incoming jobs, availability, and their verified profile.

### Core Screens
1. Splash → Location & Language onboarding — **Tamil Nadu-region default suggestion applies here specifically per Req. 1.10** (this rule lives only in this app's onboarding logic, not the customer app's)
2. Phone OTP login
3. Profile setup — skill selection (controlled dropdown, stored as canonical English per Req. 5.5), experience, service radius
4. Document upload — compress client-side → send to Render `/api/documents/upload` → encrypted server-side → stored in Firestore subcollection (`workers/{id}/documents/{docId}`), each kept under Firestore's 1 MiB cap
5. Availability toggle (online/offline)
6. Incoming job requests — live list via Firestore listener, ranked by the Render matching engine
7. Accept/reject/in-progress/complete booking flow
8. Earnings/history view
9. Insurance & welfare status card (Admin-managed field, read-only here)
10. "Add someone I know" — same Proxy Worker referral flow as the customer app, reused from `workgo_core`, since a worker is equally likely to know an unconnected feature-phone peer
11. Ratings received (read-only view of their own rating history)

---

## 7. App 3 — WorkGo Cooperative Console (Admin/Organization App)

### Purpose
The governance layer that proves this is a cooperative-owned platform, not a private gig clone. Web-first, responsive, with a lighter mobile companion for on-the-go approvals.

### Core Screens
1. Admin login (Phone OTP + admin role flag — **always defaults to English per Req. 1.10**, never location-suggested)
2. **Pending Approvals** — worker/proxy-worker document review (decrypted via Render `/api/documents/:id`, restricted to authenticated admin sessions), approve/reject actions
3. **Bookings Overview** — live table of all bookings in the cooperative/society, filterable by status/date/service type
4. **Smart Demand Insights** — chart view of the Render cron job's aggregated output (Section 4), clearly labeled as a statistical forecast, not a trained AI model
5. **Worker Welfare Management** — toggle insurance/scheme enrollment status per worker (manual, off-platform-verified)
6. **Proxy Worker Verification Queue** — separate from the standard approval queue since these are call-verified by an admin, not document-verified initially
7. Organization/cooperative profile settings (name, region, admin roster)

### Data Model Note
Add `organizationId` (cooperative/federation reference) to `workers`, `bookings`, and `users` documents so the Console can filter correctly — this was flagged as future-ready in v1; it's now an active requirement since Admin is its own dedicated app and needs first-class org-scoping, not an afterthought field.

---

## 8. Updated Firestore Data Model (delta from v1)

```
users/{userId}
  - uid, phone, role, preferredLanguage, region, organizationId (nullable for customers)

workers/{workerId}
  - userId, organizationId, skills[], experienceYears
  - isProxy, proxyReferrerId, phoneForCalling
  - verificationStatus, avgRating, totalRatings
  - location (geopoint), serviceRadiusKm, availabilityStatus
  - insuranceStatus, welfareSchemeId
  - documents/  (subcollection — each doc under 1 MiB, encrypted server-side by Render)

bookings/{bookingId}
  - customerId, workerId, organizationId
  - serviceType, isEmergency, scheduledAt, status
  - location (geopoint), paymentStatus, amount, invoiceId

organizations/{organizationId}
  - name, region, adminUserIds[]

ratings/{ratingId}
  - bookingId, workerId, customerId, stars, comment

languagePacks/{langCode}
  - version, entries{}

demandStats/{regionId_dateKey}
  - bookingCount, topServiceType, computedAt   ← now written by Render cron job, not client
```

---

## 9. Phased Implementation Plan (Cross-App, Coordinated)

| Phase | Backend (Render) | App 1 (Customer) | App 2 (Karya) | App 3 (Console) |
|---|---|---|---|---|
| **0 — Foundation** | Scaffold Express app, connect Firebase Admin SDK, deploy skeleton to Render | Scaffold Flutter app, wire `workgo_core` dependency | Same | Same |
| **1 — Shared Core** | — | Build out `workgo_core`: theme, localization loader, API client, shared models (done once, used by all three) | consumes core | consumes core | consumes core |
| **2 — Auth** | Verify Firebase ID tokens on incoming requests | Phone OTP flow | Phone OTP flow | Phone OTP + admin flag check |
| **3 — Profiles & Documents** | `/api/documents/upload` + `/api/documents/:id` endpoints, encryption logic | — | Worker profile + document upload flow | Approval queue UI (consumes same endpoints) |
| **4 — Matching & Booking** | `/api/match-workers`, booking status endpoints | Search, booking creation, live tracker | Incoming job requests, accept/reject | Bookings Overview table |
| **5 — Payments & Notifications** | Razorpay webhook verification, FCM trigger on status change | Payment + invoice screens | Job completion → earnings | — |
| **6 — Insights & Governance** | Cron job for demand aggregation | — | — | Smart Demand Insights, Welfare Management |
| **7 — Proxy Worker Flow** | Manual booking-log endpoint for call-based bookings | "Add someone I know" form | Same form (shared widget from core) | Proxy Verification Queue |
| **8 — Polish** | Rate limiting, error handling hardening | Dark/light QA, sound/haptic feedback pass | Same | Responsive web breakpoint QA (primary focus here) |

**Coordination rule:** Backend endpoints for a phase must exist and be tested (e.g., via Postman) *before* any app team starts wiring UI to them — this prevents three teams blocking on each other mid-sprint.

---

## 10. Do's and Don'ts (v2 — Updated for Multi-App + Render)

### Do
- ✅ Put all shared logic in `workgo_core` — theme, localization, models, API client. Never copy-paste between the three app folders.
- ✅ Route every sensitive operation (document decryption, payment verification, admin approvals) through the Render backend — no app should hold Firebase Admin credentials or perform these operations client-side.
- ✅ Keep each app's screen set strictly scoped to its role per Sections 5–7 — if a screen doesn't belong to that audience, it doesn't belong in that app.
- ✅ Test Render endpoints independently (Postman/curl) before wiring any Flutter UI to them.
- ✅ Keep the demand-forecast labeled honestly as a statistical aggregation job in both code comments and UI copy.
- ✅ Scope every `workers`/`bookings` query by `organizationId` in the Admin Console — never show cross-cooperative data by default.
- ✅ Wrap every localized string in the shared `SafeText` widget (Section 12) — never a raw `Text()` — so overflow handling is automatic and consistent across all three apps.
- ✅ Test every screen's text in all three languages before marking it "done" — Tamil/Hindi strings are frequently longer than their English source and are the most common source of layout breaks; English-only QA is not sufficient sign-off.

### Don't
- 🚫 Do not duplicate theme/localization/model code across the three apps — this defeats the entire purpose of the multi-app split and will cause the apps to drift out of sync.
- 🚫 Do not let any Flutter app call Firestore directly for sensitive writes (document uploads, payment status, admin approvals) — those must go through Render.
- 🚫 Do not add worker-only or admin-only screens into the customer app "just in case" — that reintroduces the bloat this architecture exists to avoid.
- 🚫 Do not hardcode the Render backend URL — use environment-based config (`--dart-define` or a config file per build flavor) so dev/staging/prod can point to different backend URLs without code changes.
- 🚫 Do not skip the Render cold-start mitigation before any live demo — a stalled first request in front of judges is an avoidable failure.
- 🚫 Do not seed or hardcode sample data anywhere — same rule as v1, still absolute.
- 🚫 Do not use raw `Text()` widgets for localized content, and do not build layouts assuming English-length strings — every label-holding container (buttons, chips, cards, tab bars) must be tested against the longest real string across all three languages, not just the English default.

---

## 11. Non-Functional Notes

- **App size target:** each app should stay meaningfully smaller than a single combined app would have been — track this explicitly (`flutter build apk --analyze-size`) as a demo talking point ("WorkGo customer app is X MB because it doesn't carry worker-verification or admin code").
- **Security:** Firebase service-account credentials live only in Render's environment variables, never in any Flutter app bundle or public repo.
- **Cross-app consistency:** since all three apps share `workgo_core`'s theme and localization packs, a color or translation update made once propagates to all three on next build — verify this is genuinely true before the demo, not just structurally intended.

---

## 12. UI Excellence Standards (Cross-App, Non-Negotiable)

This section exists because "top-notch UI" is only real if it's a system every screen inherits automatically — not a polish pass bolted on in Phase 8. Every rule below lives in `workgo_core` and is inherited by all three apps by construction.

### 13.1 The `SafeText` Widget — Solving Overflow at the Root
Build one shared widget in `workgo_core/widgets/safe_text.dart` that **every screen in every app uses instead of Flutter's raw `Text()`**. It should:
- Accept `maxLines` (default 1 for buttons/chips/labels, 2 for card titles, higher for body copy).
- Always set `overflow: TextOverflow.ellipsis` as the default behavior — never let text silently clip or push layout out of bounds.
- Auto-shrink font size within a safe range (via `AutoSizeText` package, or a custom `FittedBox` wrapper) for tight containers like bottom-nav labels and chip buttons, where even one truncated character looks broken — ellipsis for body text, gentle auto-shrink for short UI labels.
- On tap-and-hold (long press) of a truncated label, optionally show the full text in a lightweight tooltip/snackbar — cheap to add, meaningfully removes user confusion without adding visual clutter.
- Because all localized strings are pulled through this one widget, a language-pack update that makes a string longer (e.g., an English label translated to a longer Tamil phrase) **cannot** create a new overflow bug anywhere in the app — the widget's rules apply uniformly by construction, not by developer memory.

### 13.2 Layout Rules That Prevent Overflow Before It Happens
- No fixed-width containers around text — use `Expanded`/`Flexible` inside `Row`s so text has room to shrink or wrap before it overflows its parent.
- Every button, chip, and tab-bar label must be QA'd against the **longest actual string across all three language packs** (not just English) before a screen is marked complete — add this as a literal checklist item in each screen's "done" definition, not an afterthought.
- Icons stay fixed-size; text is always the flexible element in any icon+label pairing — never let a label push an icon off-screen or the reverse.

### 13.3 Visual Polish System (applies to all three apps identically)
- **Spacing grid:** all padding/margins use a strict 4/8/16/24/32 scale — no arbitrary pixel values anywhere in the codebase. Keeps every screen feeling consistent without manual eyeballing.
- **Motion:** page transitions, button presses, and card taps get a subtle, consistent animation curve (e.g., `Curves.easeOutCubic`, 200–250ms) — defined once in `workgo_core/theme`, never re-implemented per screen.
- **Loading states:** use skeleton/shimmer placeholders (not blank screens or bare spinners) for worker lists, bookings, and dashboard data — this alone makes the app feel dramatically more polished for close to zero extra engineering effort.
- **Empty states:** every list/screen that can be empty (no bookings yet, no workers nearby, no pending approvals) needs a designed empty state — icon + short localized message + a relevant CTA — never a blank white/dark screen, which reads as broken rather than "nothing here yet."
- **Touch targets:** minimum 48x48dp on every tappable element, honoring the "thumb-friendly, muscle-memory" principle from Section 4.2 of v1 — this also directly serves accessibility.
- **Contrast:** verify purple/yellow accent combinations meet at least WCAG AA contrast in both themes — a striking palette that's hard to read fails the "top-notch UI" bar just as much as a boring one that's clear.

### 13.4 Definition of "Done" for Any Screen
A screen is not complete until it passes all of the following, in order:
1. Renders correctly with real (non-seeded) data and with **zero data** (empty state check).
2. Tested in all three languages with zero visual overflow or clipped text.
3. Tested in both dark and light themes.
4. Tested at mobile, tablet, and (where relevant) desktop breakpoints.
5. Every text element runs through `SafeText`, every spacing value comes from the 4/8/16/24/32 scale.

---

## 13. Open Decisions Before Coding Starts

1. Confirm backend framework: Express (faster to scaffold) vs. NestJS (more structure, steeper setup) — recommend **Express** given the hackathon timeline.
2. Confirm monorepo tooling: plain path-dependency packages (simplest) vs. Melos (better multi-package script management) — recommend starting with plain path dependencies, add Melos only if the team feels the friction.
3. Confirm Render plan tier for the demo window (free with uptime-ping vs. cheapest paid tier) to eliminate cold-start risk during judging.
4. Confirm final app names/icons for App 2 and App 3 for store-listing consistency (this doc proposes "WorkGo Karya" and "WorkGo Cooperative Console" as placeholders).
