# WorkGo — SIH Feature Architecture & Integration Guide
**Target Audience:** Teammates & Collaborators combining modules into the WorkGo monorepo  
**SIH Problem Statement:** 26089 (Worker Welfare, Micro-Insurance & Smart Workforce Allocation)  
**Date:** September 2026  

---

## 📌 Executive Summary
This document provides a comprehensive technical breakdown of four major engineering systems implemented in the **WorkGo** platform:
1. **AI-Based Demand Forecasting & Workforce Allocation**
2. **Interactive Analytical Charts in Overview Cockpit**
3. **Geographic Heatmap & Spatial Coverage Insights**
4. **Worker Welfare & Micro-Insurance Integration (SIH 26089)**

For each system, this guide details:
- **The "Why"**: The operational problem, architectural motivation, and algorithmic rationale.
- **The "Where"**: Exact file paths, directory structures, models, endpoints, and UI components.
- **The "What"**: Line-level changes, API contract structures, database schemas, and mathematical formulas.
- **Integration Checklist**: Step-by-step instructions for merging and preventing conflicts.

---

## 1. AI-Based Demand Forecasting & Workforce Allocation

### 1.1 The "Why" (Motivation & Business Logic)
- **Problem**: On-demand artisan/informal gig platforms suffer from chronic supply-demand volatility. Extreme weather (monsoon downpours causing electrical failures and plumbing bursts) and seasonal festival cycles (Diwali, Pongal, Eid causing spikes in painting, carpentry, and deep cleaning) cause severe regional shortages if not predicted in advance.
- **Solution**: Instead of reactive dispatch, WorkGo implements a forward-looking predictive engine that projects hourly and daily trade demand by region, identifies worker deficits, and proactively alerts or mobilizes standby artisan pools.
- **Why ONNX In-Memory Inference**: Rather than running a heavyweight Python microservice alongside the Node.js backend, the trained regression model is exported to `.onnx`. Node.js evaluates predictions in-memory within milliseconds (`onnxruntime-node`), drastically reducing latency and hosting costs.

### 1.2 File Map & Locations
```
WorkGo/
├── backend/
│   ├── ml_training/
│   │   └── train.py                     # Python model training script (RandomForest/LightGBM)
│   ├── models/
│   │   └── demand_model.onnx            # Serialized trained ONNX model
│   ├── src/
│   │   ├── services/
│   │   │   ├── demand_model.js          # ONNX runtime inference loader & feature extractor
│   │   │   ├── demand_aggregation.js    # Rolling trade volume & deficit calculation pipeline
│   │   │   ├── weather.js               # Real-time rainfall/temperature signal provider
│   │   │   └── notification_engine.js   # Automated surge alerts & standby push notifications
│   │   ├── data/
│   │   │   └── india_holidays.json      # Pan-Indian & regional festival calendar
│   │   └── routes/
│   │       ├── insights.js              # GET /api/insights/demand-forecast & allocation APIs
│   │       └── match.js                 # Geodesic radius matcher with standby pool weighting
│   └── tests/
│       ├── demand_aggregation.test.js   # Aggregation pipeline tests
│       └── insights.test.js             # Forecast API route tests
├── apps/workgo_admin_console/
│   └── lib/src/screens/
│       └── smart_demand_insights_screen.dart # Interactive trade forecast & allocation dashboard
└── apps/workgo_karya/
    ├── lib/src/services/
    │   └── karya_demand_service.dart    # Worker-side demand feed & multiplier notifications
    └── lib/src/screens/
        └── karya_home_screen.dart       # High-demand zone badges & earnings broadcast
```

### 1.3 Key Implementations & Algorithms
1. **Feature Vector Engineering (`demand_model.js` & `train.py`)**:
   Inputs feeding into the ONNX model include:
   - `dayOfWeek` (0-6) & `hourOfDay` (0-23)
   - `isHoliday` & `holidayProximityDays` (from `india_holidays.json`)
   - `rainIntensityMm` & `temperatureC` (from `weather.js`)
   - `activeWorkerCount` & `historical30DayTradeVelocity`
   - `unfulfilledBookingRatio`
2. **Deficit / Shortage Score Formula**:
   $$\text{Shortage Ratio} = \frac{\text{Projected Demand} - \text{Active Supply}}{\max(\text{Active Supply}, 1)}$$
   - If Shortage Ratio $> 0.35$ (35% deficit): High-alert surge flag is raised.
   - Triggers `notification_engine.js` to dispatch FCM notifications to standby artisans offering peak surge earnings multipliers (1.25x – 1.5x).
3. **Admin Controls (`smart_demand_insights_screen.dart`)**:
   - Live Trade Cards: Plumbing, Electrical, Carpentry, Masonry, Painting.
   - Real-time comparison between scheduled bookings vs. predicted volume.
   - One-click "Mobilize Standby Pool" button that updates worker availability radius in Firestore.

---

## 2. Analytical Charts in Overview Cockpit

### 2.1 The "Why" (Motivation & Business Logic)
- **Problem**: Administrators managing multi-district worker cooperatives require immediate visual clarity on gross volume, settled cashflow, booking drop-offs, and compliance rates. Tabular numbers make it impossible to detect micro-trends or anomalous cancellation spikes.
- **Solution**: The Overview Cockpit (`admin_dashboard_screen.dart`) was re-architected with reactive SVG/canvas vector charts and real-time Firestore listeners, providing instant drill-down without full page reloads.

### 2.2 File Map & Locations
```
WorkGo/
└── apps/workgo_admin_console/
    └── lib/src/screens/
        ├── admin_dashboard_screen.dart  # Redesigned Cockpit with real-time charts & KPI metrics
        └── admin_theme.dart             # Curated design tokens, typography, and palette (AX design system)
```

### 2.3 Key Visual Components & Implementations
1. **Financial & GMV Volume Spline Chart**:
   - Dual-line smooth cubic Bezier visualization tracking Gross Booking Value (GBV) vs. Net Settled Volume.
   - Granular time filters: Today (hourly), 7-Day Rolling, 30-Day Monthly, and Quarter-to-Date.
   - Automated 2% Welfare Dividend calculation curve showing real-time fund accumulation.
2. **Booking Lifecycle Radial / Donut Distribution**:
   - Interactive breakdown of booking statuses: `Settled (Paid)`, `Active (In-Progress)`, `Pending Confirmation`, `Cancelled`.
   - Dynamic touch/hover inspection revealing exact counts and cancellation loss rates.
3. **Trade Performance Vertical Bar Comparisons**:
   - Compares total completed jobs and average hourly ticket size across trades.
   - Highlights top-performing guild cooperatives and identifies lagging trades requiring artisan recruitment.
4. **Real-time Reactive Streams**:
   - Directly binds to Firestore streams (`_bookingService.streamAllBookings()` and `_workerService.streamAllWorkers()`), updating chart geometries dynamically as workers complete jobs in the field.

---

## 3. Geographic Heatmap & Spatial Coverage Insights

### 3.1 The "Why" (Motivation & Business Logic)
- **Problem**: Artisans are distributed across diverse taluks and municipal wards. Conventional map pins cluster on top of each other, making it impossible to see where "service deserts" (areas with high customer demand but zero available workers) exist. External map APIs (e.g., Google Maps) also impose heavy billing quotas and slow down aggregate dashboard rendering.
- **Solution**: Built an offline-capable, high-performance choropleth and density heatmap engine using optimized local GeoJSON boundary coordinates for Indian states and districts, projected with a custom Flutter `CustomPainter`.

### 3.2 File Map & Locations
```
WorkGo/
└── apps/workgo_admin_console/
    ├── assets/geo/
    │   ├── india_state_opt.json         # Lightweight optimized boundary coordinates (Indian States)
    │   └── india_district_opt.json      # Lightweight boundary coordinates (Indian Districts)
    └── lib/src/screens/
        └── geographic_insights_screen.dart # Interactive Choropleth, Heatmap & District Inspector
```

### 3.3 Key Implementations & Spatial Logic
1. **Optimized GeoJSON Storage**:
   - Raw India district boundary shapefiles are typically 20MB+.
   - Optimized, compressed, and smoothed to $< 500\text{ KB}$ using topological coordinate quantization without losing visible boundary fidelity.
2. **Coordinate Normalization & Canvas Projection**:
   - WGS84 coordinates ($[\text{longitude}, \text{latitude}]$) are projected into local Flutter `Canvas` Cartesian space using an equirectangular transformation with zoom, pan, and hit-test matrix transformations.
3. **Heatmap Gradient Thresholds**:
   - **Emerald Green (Normal)**: Supply/demand ratio $\ge 1.0$ (adequate artisan coverage).
   - **Amber / Gold (Warning)**: Supply/demand ratio between $0.6$ and $0.99$.
   - **Crimson / Rose (Critical Deficit)**: Supply/demand ratio $< 0.6$ with $> 5$ unfulfilled requests.
4. **District Inspection Drawer**:
   - Clicking or hovering any district opens a side panel showing: District Name, Registered Workers, Active Online Count, Open Bookings, and Top In-Demand Trades.

---

## 4. Worker Welfare & Micro-Insurance Integration (SIH 26089)

### 4.1 The "Why" (Motivation & Business Logic)
- **The Core Mandate**: Gig workers and informal artisans lack institutional security. Under SIH Problem Statement 26089:
  1. **Autonomous Funding**: Every settled booking contributes strictly 2% into a collective welfare corpus funding government-backed micro-insurance:
     - **PMJJBY** (*Pradhan Mantri Jeevan Jyoti Bima Yojana*): ₹2,00,000 renewable life insurance (₹436/year).
     - **PMSBY** (*Pradhan Mantri Suraksha Bima Yojana*): ₹2,00,000 accidental death/full disability cover (₹20/year).
  2. **Encrypted Medical Document Vault**: Medical prescriptions, hospital discharge summaries, and injury scene photos contain sensitive personal health data protected under the Digital Personal Data Protection (DPDP) Act. All documents are AES-256-CBC encrypted at the backend; direct client Firestore writes are locked down.
  3. **Multi-Factor Claim Confidence Engine**: Prevents fraudulent claims through a pure algorithmic scoring engine combining medical confirmation, customer corroboration, SOS beacon cross-checks, and AI image tamper detection.
  4. **Immutable Decision Audit Snapshot**: The historical confidence score and threshold tier are permanently snapshotted when a decision is made, guaranteeing audit transparency for government regulators.

### 4.2 File Map & Locations
```
WorkGo/
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   │   ├── documents.js             # AES-256-CBC encrypted document upload & decryption proxy
│   │   │   └── welfare.js               # Claims submission, detail query, verify & decision routes
│   │   └── services/
│   │       └── welfare_scoring.js       # Pure scoring engine (computeClaimConfidence & getApprovalThreshold)
│   └── tests/
│       ├── documents.test.js            # Encrypted vault tests
│       ├── welfare_scoring.test.js      # Pure scoring math tests
│       └── welfare_routes.test.js       # API route integration tests
├── packages/workgo_core/
│   ├── lib/src/
│   │   ├── models/
│   │   │   ├── welfare_claim.dart       # WelfareClaim, ClaimFactors, ClaimConfidenceScore models
│   │   │   └── worker.dart              # Worker model with createdAt backfill support
│   │   └── services/
│   │       ├── welfare_service.dart     # Welfare API client (submit, fetch, verify, decide)
│   │       └── booking_service.dart     # Additive streamWorkerBookings & getWorkerRecentBookings
│   └── test/
│       ├── welfare_claim_decoding_test.dart    # 4 fixture-decoding unit tests
│       └── worker_created_at_backfill_test.dart# Tenure backfill unit tests
├── apps/workgo_karya/
│   └── lib/src/screens/
│       ├── welfare_claim_submission_screen.dart # Worker 3-step encrypted document submission UI
│       └── worker_welfare_screen.dart          # Status tracking & claim filing card
├── apps/workgo_admin_console/
│   └── lib/src/screens/
│       └── worker_welfare_management_screen.dart # Master-Detail review cockpit & Corpus roster
└── firestore.rules                              # Subcollection & claims locked-down security rules
```

### 4.3 Detailed Architecture & Data Flow

#### A. Document Encryption Pipeline (`backend/src/routes/documents.js`)
- Client apps cannot write directly to `workers/{workerId}/documents/{docId}` (`firestore.rules` enforces `allow write: if isAdmin();`).
- Uploads are posted via `multipart/form-data` to `POST /api/documents/upload`.
- The server generates a random 16-byte IV, encrypts the file buffer with `AES-256-CBC` using the server vault key, and writes the ciphertext to the private Firebase Storage/Firestore vault.
- Supported welfare document types:
  - `welfareCertificate` (Mandatory Doctor/Medical Certificate)
  - `welfareInjuryPhoto` (Injury scene photograph)
  - `welfareHospitalRecord` (Hospital admission / discharge summary)

#### B. Pure Scoring Engine (`backend/src/services/welfare_scoring.js`)
1. **Submission Gate**: Doctor's certificate is a **hard gate**. If `doctorCertificateDocId` is missing or its stored `docType !== "welfareCertificate"`, the backend rejects submission with **HTTP 400**. The certificate is not part of the variable percentage math—it is a prerequisite.
2. **Dual Weight Tables**:
   - **Job-Linked Claims** (`claim.bookingId` present):
     - Doctor Direct Call Confirmed: **35%**
     - Hospital Record Document Provided: **25%**
     - Customer Dispatch Incident Corroborated: **20%**
     - SOS Beacon Log Corroborated: **10%**
     - Injury Photo Passes Tamper Check: **10%**
   - **Non-Job Claims** (`claim.bookingId` absent — off-duty accident or natural illness):
     - Doctor Direct Call Confirmed: **45%**
     - Hospital Record Document Provided: **30%**
     - SOS Beacon Log Corroborated: **15%**
     - Injury Photo Passes Tamper Check: **10%**
     *(Customer call is completely excluded and hidden from the admin UI).*
3. **Tenure-Based Rolling 24-Month Threshold Tiers**:
   Calculated dynamically via `getApprovalThreshold(workerId, db)`:
   - **Tier 1 (New Worker, 0–1 prior claims in 24m)**: Required Threshold = **50%**
   - **Tier 2 (Moderate Frequency, 2 prior claims in 24m)**: Required Threshold = **75%**
   - **Tier 3 (High Frequency, 3+ prior claims in 24m)**: Required Threshold = **90%**
4. **Trust Bonus**:
   - If worker platform tenure $> 6\text{ months}$ and average customer rating $\ge 4.5\star$, an automatic **+5%** trust bonus is awarded (capped at $100\%$).
5. **Anti-Tampering & Override Guards**:
   - Every admin verification check requires an administrative note of at least **20 characters** (e.g., `doctorCallNote`, `customerCallNote`, `sosNote`).
   - If an injury photo is flagged as synthetic/manipulated by AI checks, it contributes $0\%$ to the score unless an admin explicitly supplies `photoOverride: true` with a justification note of $\ge 20$ characters.

#### C. Worker App Privacy Rule (`workgo_karya`)
- **Zero Score Exposure**: Artisans are never shown internal confidence scores, factor breakdowns, or threshold percentages.
- The worker app UI strictly displays status chips (`Under Review`, `Approved`, `Rejected`), settlement advice, and helpline resources.

#### D. Admin Review & Decision Cockpit (`workgo_admin_console`)
- **Master-Detail Cockpit** (`worker_welfare_management_screen.dart`):
  - **Tab 0 ("Claims Review & Settlement")**:
    - Filterable claim queue (All, Pending, Approved, Rejected).
    - Decrypted document previewer with in-memory base64 decoding for instant image/PDF viewing.
    - Interactive corroboration checklist with live character count validation ($\ge 20$ chars).
    - Real-time confidence gauge displaying Base Score, Trust Bonus, Active Weight Model, and Threshold compliance pill.
    - Settlement decision modal requiring an administrative justification note ($\ge 10$ chars).
  - **Tab 1 ("Insurance Corpus & Artisan Roster")**:
    - Verbatim preserved 2% corpus volume counters.
    - Active coverage percentage counter.
    - Artisan toggle switch list updating `insuranceStatus` directly in Firestore.

---

## 5. Teammate Merging & Integration Checklist

When combining another branch or sub-project with this repository, follow these steps to avoid regressions:

### 1. Backend Integration (`WorkGo/backend`)
- [ ] Ensure `.env` contains:
  ```env
  PORT=5000
  NODE_ENV=development
  DOCUMENT_ENCRYPTION_KEY=<32-character-secure-hex-key>
  FIREBASE_SERVICE_ACCOUNT_KEY=./config/serviceAccountKey.json
  ```
- [ ] Run backend automated test suites:
  ```bash
  cd backend
  npm test
  ```
  *Expected result: 12 test suites passing, 73/73 tests passed.*

### 2. Firestore Security Rules (`WorkGo/firestore.rules`)
- [ ] Confirm the subcollection rule for worker documents is preserved:
  ```javascript
  match /workers/{workerId}/documents/{docId} {
    allow read: if isAuthenticated() && (isAdmin() || workerId == request.auth.uid || ...);
    allow write: if isAdmin(); // Enforces encrypted backend upload pipeline
  }
  ```
- [ ] Confirm `welfare_claims/{claimId}` preserves user/proxy read permissions and blocks direct client updates:
  ```javascript
  match /welfare_claims/{claimId} {
    allow read: if isAuthenticated() && (isAdmin() || resource.data.workerId == request.auth.uid || ...);
    allow create, update, delete: if isAdmin();
  }
  ```

### 3. Flutter Core Package (`WorkGo/packages/workgo_core`)
- [ ] Verify `welfare_claim.dart` has zero dual-writing (strictly uses `description` and `bookingId`, not `incidentDescription` or `relatedBookingId`).
- [ ] Run core tests:
  ```bash
  cd packages/workgo_core
  flutter test
  ```
  *Expected result: All tests passed (109/109).*

### 4. Admin & Worker Apps (`workgo_admin_console` & `workgo_karya`)
- [ ] Run static code analysis across all apps:
  ```bash
  cd apps/workgo_admin_console && flutter analyze
  cd apps/workgo_karya && flutter analyze
  ```
  *Expected result: 0 errors / 0 issues found.*
- [ ] When merging `worker_welfare_management_screen.dart`, verify that the Customer Call checkbox remains enclosed in `if (claim.isBookingLinked) ...` so non-booking claims do not render uncorroborated customer factors.

---

## 6. Summary Table: Files Changed & Purpose

| System | Component / File | Primary Purpose / What Changed |
| :--- | :--- | :--- |
| **AI Demand** | `backend/ml_training/train.py` | Trains Multi-Factor Random Forest regressor with weather & holiday features. |
| **AI Demand** | `backend/models/demand_model.onnx` | High-speed serialized model evaluated in-memory by Node.js. |
| **AI Demand** | `backend/src/services/demand_model.js` | Runs ONNX runtime inference without requiring a Python microservice. |
| **AI Demand** | `backend/src/services/weather.js` | Real-time rainfall & temperature signal integration. |
| **AI Demand** | `backend/src/routes/insights.js` | REST APIs delivering projected trade volume and shortage ratios. |
| **AI Demand** | `apps/workgo_admin_console/.../smart_demand_insights_screen.dart` | Admin UI displaying forward curves and standby pool mobilization triggers. |
| **Charts Cockpit** | `apps/workgo_admin_console/.../admin_dashboard_screen.dart` | Real-time reactive spline, donut, and bar charts for GMV, bookings, and trades. |
| **Geographic** | `apps/workgo_admin_console/assets/geo/india_*.json` | Optimized offline Indian state and district GeoJSON vector geometries. |
| **Geographic** | `apps/workgo_admin_console/.../geographic_insights_screen.dart` | CustomPainter choropleth/heatmap showing worker deficits and district drawer. |
| **Welfare (SIH)**| `backend/src/services/welfare_scoring.js` | Pure mathematical scoring engine with dual tables and rolling tenure tiers. |
| **Welfare (SIH)**| `backend/src/routes/documents.js` | AES-256-CBC encrypted document vault pipeline for medical records and photos. |
| **Welfare (SIH)**| `backend/src/routes/welfare.js` | Hard-gated claim submission, factor verification, and immutable decision APIs. |
| **Welfare (SIH)**| `packages/workgo_core/.../welfare_claim.dart` | Clean Dart model with factor breakdowns and un-mocked backend response matching. |
| **Welfare (SIH)**| `apps/workgo_karya/.../welfare_claim_submission_screen.dart` | Worker 3-step encrypted document submission UI with zero score exposure. |
| **Welfare (SIH)**| `apps/workgo_admin_console/.../worker_welfare_management_screen.dart` | Master-Detail review cockpit, decrypted document viewer, and preserved 2% corpus roster. |
