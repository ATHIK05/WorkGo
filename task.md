# WorkGo — Development Task Tracker (Refined v2)

> **Project:** WorkGo | SIH 2026 — SIH26089
> **Firebase Project:** `workgo-sih2026` | **Monorepo Root:** `d:\WorkGo\`
> **Auth Stack:** Firebase Email/Password + Firestore Roles
> **Localization:** `easy_localization ^3.0.8` (view-layer `.tr()` translation across EN/HI/TA)

---

## Phase 0 — Foundation (Firebase + Monorepo Scaffold)

- [x] Create Firebase project `workgo-sih2026`
- [x] Set `.firebaserc` (default alias → workgo-sih2026)
- [x] Create `firebase.json` (Firestore rules + Hosting config)
- [x] Create `firestore.rules` (Phase 0 open auth rules)
- [x] Create `firestore.indexes.json`
- [x] Create `.gitignore` (blocks service keys, google-services.json from git)
- [x] Scaffold `packages/workgo_core` (Flutter package template)
- [x] Scaffold `apps/workgo_customer` (Flutter app — `com.workgo.customer`)
- [x] Scaffold `apps/workgo_karya` (Flutter app — `com.workgo.karya`)
- [x] Scaffold `apps/workgo_admin_console` (Flutter app — `com.workgo.console`, web+android)
- [x] Scaffold `backend/` (Node.js/Express structure with all routes + services)
- [x] Run `flutter pub get` on all 4 Flutter packages ✅
- [x] Run `npm install` in `backend/` ✅
- [ ] **[MANUAL]** Enable Firebase services in console:
  - [ ] Authentication → **Email/Password** provider (Enable)
  - [ ] Firestore Database (start in test mode)
  - [ ] Cloud Messaging (FCM)
  - [ ] Hosting (optional for now)
- [ ] **[MANUAL]** Register 3 Android apps in Firebase Console → download `google-services.json` for each:
  - [ ] `com.workgo.customer` → `apps/workgo_customer/android/app/google-services.json`
  - [ ] `com.workgo.karya` → `apps/workgo_karya/android/app/google-services.json`
  - [ ] `com.workgo.console` → `apps/workgo_admin_console/android/app/google-services.json`
- [ ] Run `flutterfire configure` for each app (generates `firebase_options.dart`)
- [ ] `firebase init firestore` (deploy Phase 0 rules)

---

## Phase 1 — workgo_core: Shared Package & Localization

- [x] `lib/src/theme/colors.dart` — WorkGoColors (purple/yellow palette)
- [x] `lib/src/theme/spacing.dart` — WorkGoSpacing (4/8/16/24/32 scale)
- [x] `lib/src/theme/motion.dart` — WorkGoMotion (easeOutCubic, 150/220/350ms)
- [x] `lib/src/theme/app_theme.dart` — WorkGoTheme.dark() + WorkGoTheme.light()
- [x] `lib/src/localization/locale_config.dart` — WorkGoLocale setup for `easy_localization`
- [x] `assets/lang/en.json` — English translation pack (auth, navigation, roles, errors)
- [x] `assets/lang/hi.json` — Hindi translation pack
- [x] `assets/lang/ta.json` — Tamil translation pack
- [x] `lib/src/models/app_user.dart` — AppUser model (email, displayName, role, preferredLanguage, region)
- [x] `lib/src/models/worker.dart` — Worker model
- [x] `lib/src/models/booking.dart` — Booking model
- [x] `lib/src/models/rating_org_demand.dart` — Rating, Organization, DemandStat
- [x] `lib/src/widgets/safe_text.dart` — SafeText (the mandatory text widget with autoShrink)
- [x] `lib/src/widgets/skeleton_loader.dart` — SkeletonLoader
- [x] `lib/src/widgets/empty_state.dart` — EmptyStateWidget
- [x] `lib/src/firebase/auth_service.dart` — AuthService (Email/Password sign-up, sign-in, password reset, email verification, user upsert)
- [x] `lib/src/api_client/workgo_api_client.dart` — WorkGoApiClient (Render HTTP)
- [x] `lib/workgo_core.dart` — Barrel export
- [x] Unit tests for `workgo_core` passing (100%)
- [x] Zero analyzer issues in `workgo_core`

---

## Phase 2 — Immersive Auth UI & Root Apps

- [x] `AuthRoleBadge` widget with role-colored accent glow (Customer, Worker, Admin)
- [x] `AuthTextField` widget with animated focus glow, eye toggle, and field validation
- [x] `SignInForm` widget with validation, forgot-password trigger, gradient CTA
- [x] `SignUpForm` widget with full name, email, password, confirm password validation
- [x] `ForgotPasswordForm` widget with password reset trigger
- [x] `AuthShell` scaffold:
  - [x] Animated radial gradient background
  - [x] Floating organic glow orbs with trigonometric motion
  - [x] Frosted glassmorphism card container (BackdropFilter blur 24)
  - [x] Interactive live language switcher pill (EN / HI / TA)
  - [x] Shake animation on invalid credentials/errors
  - [x] Smooth animated transitions between auth modes
  - [x] Auto-upsert to Firestore `users/{uid}` on signup
- [x] `workgo_customer/lib/main.dart` wired with EasyLocalization + WorkGoTheme + AuthShell + Customer HomeScreen
- [x] `workgo_karya/lib/main.dart` wired with EasyLocalization + WorkGoTheme + AuthShell + Worker Availability & KPI Dashboard
- [x] `workgo_admin_console/lib/main.dart` wired with EasyLocalization + WorkGoTheme + AuthShell + Cooperative Governance Portal
- [x] Zero analyzer issues across all 3 apps

---

## Next Phases

- [ ] **Phase 3** — Profiles & Document Encryption (AES-256 Render proxy)
- [ ] **Phase 4** — Matching & Booking Core (Customer map/list & Worker dispatch)
- [ ] **Phase 5** — Payments & Notifications (Razorpay + FCM push)
- [ ] **Phase 6** — Demand Insights & Welfare (Nightly statistical demand forecast + Welfare scheme management)
- [ ] **Phase 7** — Proxy Worker Flow ("Add Someone I Know")
- [ ] **Phase 8** — Polish, QA & Multi-Platform Web/Android Build
