# Temidove CRM — project brief

Read this before making changes. It's the handoff context from planning
to implementation — the "why," not just the "what."

## What this is

An offline-first Windows desktop CRM for **Temidove Smart Solutions**
(a Kampala training provider — English, computer skills, accounting,
video editing, etc.), replacing two things they currently run in
parallel and manually reconcile:

1. A PHP/MySQL web app (`legacy/Temidove_Online_PHP/`) that tracks
   course inquiries and enrollment status.
2. Excel workbooks (`legacy/Sample_Payment_Tracker.xlsx`) — one per
   teaching batch — that manually track monthly fee payments, due
   dates, and which mobile money agent a student paid through.

**Read `legacy/NOTES.md` first** — it documents exactly how the old
systems map onto the new schema and, importantly, where they *don't*
reconcile cleanly (the "offer 1/2/3" vs named-batch mismatch). That
gap is the actual reason this project exists, not just "make it look
nicer than Excel."

## Requirements confirmed with the client

- **Multi-PC, sync eventually.** Not needed for v1, but the schema
  must not need a rewrite when it arrives. This is why every table in
  `lib/database/database.dart` uses a UUID text primary key plus
  `createdAt` / `updatedAt` / `isDeleted` — see the `SyncableColumns`
  mixin. When a sync layer is built, it'll be a Laravel API on the
  existing Contabo VPS (matches their standard stack elsewhere), with
  clients pushing/pulling deltas keyed on `updatedAt`. Don't build that
  now — just don't do anything to the schema that would block it later
  (no autoincrement ints, no assuming a single writer).
- **Flexible payment schedules.** Batches vary in length and fee — not
  a fixed 3-month plan. `Batches.durationMonths` and `.monthlyFee`
  drive schedule generation (`PaymentDao.generateScheduleForEnrollment`),
  and `Enrollments.customFee` allows a per-student override (discounts,
  late joiners).
- **Payment reminders are in v1 scope**, not a later nice-to-have. See
  `lib/features/reminders/reminder_service.dart` — deliberately simple
  (a `wa.me` deep link, not a paid SMS/WhatsApp Business API), because
  this is a desktop app with no message-sending budget. Every reminder
  sent gets logged to `ReminderLog` so two staff members don't message
  the same overdue student twice.

## Architecture

- **Flutter, Windows desktop target.** Local storage is SQLite via
  Drift (`lib/database/database.dart`), NOT shared prefs / hive / etc —
  this data is relational (students ↔ enrollments ↔ batches ↔
  payments) and the queries need real joins.
- **Drift code generation.** `database.g.dart` and each `*_dao.g.dart`
  are generated, not checked in as hand-written. Run:
  ```
  dart run build_runner build --delete-conflicting-outputs
  ```
  before the app will compile. The CI workflow
  (`.github/workflows/build-windows.yml`) does this automatically.
- **State management:** `provider`, kept deliberately minimal (one
  `AppDatabase` instance provided at the root). Don't reach for
  riverpod/bloc unless the screen complexity actually demands it —
  this is a back-office tool for a handful of staff, not a
  consumer app.
- **Excel import** (`lib/features/import/excel_batch_importer.dart`)
  was reverse-engineered against ONE real sample file. It parses by
  matching header text loosely (already-observed inconsistent
  spellings: "Agenecy No" vs "Agency No"), not fixed column positions,
  because these are hand-edited spreadsheets. **Before trusting this on
  real client data, get 2-3 more real batch files and confirm the
  parser still works** — see the TODO comments in that file for
  specifics.

## Current state (post-completion pass)

The v1 feature set described below is built and wired end-to-end,
including a full UI/branding pass and real admin-gated login (the
client asked for both explicitly — see "UI/branding pass" and "Auth"
below). What exists:

- Full Drift schema, all 7 tables (`lib/database/database.dart`). Note:
  the `Batches` table's data class is `BatchData`, not `Batch` — it was
  originally named `Batch` but that collides with drift's own `Batch`
  helper class (used by `batch((b) { ... })` in the DAOs), which doesn't
  show up until you actually compile. Keep this in mind if you add a new
  table whose obvious data-class name shadows a drift/Dart built-in.
- DAOs for all tables, with the payment-schedule-generation and
  overdue-status logic fully implemented
  (`lib/database/daos/payment_dao.dart` is the one to read most
  carefully — it's the core business logic), plus join-heavy read
  methods (`EnrollmentDao.watchForBatch`/`watchForStudent`,
  `PaymentDao.watchForEnrollment`) added to support the screens below.
- Reminder service (wa.me link building + send logging), with a
  "Record payment" action alongside "Remind" on both the payments
  dashboard and the student detail screen
  (`lib/features/payments/record_payment_dialog.dart`).
- Excel batch-tracker importer: parses, previews, **and commits** —
  `lib/features/import/excel_import_committer.dart` turns a confirmed
  `ParsedBatchSheet` into real `Batches`/`Students`/`Enrollments`/
  `Payments` rows once staff pick a department and confirm the
  fee/duration in `ImportScreen`. Payments are written from each
  month's actual due date/status/paid info in the sheet, not
  regenerated from a fixed monthly cadence, so real payment history
  survives the import.
- CSV importer for the old PHP app's data
  (`lib/features/import/csv_legacy_importer.dart`) — courses/users/
  registrations exported as CSV (not parsed from the `.sql` dump; see
  the file header for why) map to Departments/Staff/Students+Enrollments.
  No payment data is fabricated from this path — the old app never
  tracked fees (see `legacy/NOTES.md`).
- App shell (`lib/app_shell.dart`) with 6-tab navigation (Dashboard /
  Payments / Departments / Students / Staff / Import) — the last two
  are admin-only, see "Auth" below — gated behind login/first-run
  admin setup (`lib/features/auth/auth_gate.dart`).
- Departments screen: full grid with add/edit, matches old
  `departments.php`, tapping a card drills into...
- Batches screen (`lib/features/batches/batches_screen.dart`): add/edit
  batches within a department (old `offers.php`), tapping a batch
  drills into...
- Batch students screen (`lib/features/students/batch_students_screen.dart`):
  students enrolled in that batch (old `clients.php`), with an "Enroll
  student" flow that creates/matches a Student, an Enrollment, and
  generates the payment schedule via `PaymentDao.generateScheduleForEnrollment`.
- Students screen: search box + status filter chips wired to
  `StudentDao.search()`, add-student dialog, tap-through to...
- Student detail screen (`lib/features/students/student_detail_screen.dart`):
  status + staff-assignment dropdowns, every enrollment with its full
  payment schedule (record payments inline), and an editable notes
  field — the equivalent of old `dashboard.php`'s edit/view modals.
- Staff screen: roster CRUD (full name/username/role/password),
  reachable only by an admin — see "Auth" below.
- Payments dashboard: full due/overdue list with working
  one-tap-reminder and one-tap "Record payment".
- Windows platform scaffolding (`windows/`, generated via
  `flutter create`) — this was **missing entirely** at handoff, which
  meant `.github/workflows/build-windows.yml`'s `flutter build windows`
  step could never have succeeded. If a build platform folder ever goes
  missing again (e.g. after a bad merge), regenerate it with
  `flutter create --platforms=windows --org com.temidove --project-name temidove_crm .`
  — it only fills in missing platform files, it won't touch `lib/`.
- A widget smoke test (`test/widget_test.dart`) boots the real app
  against an in-memory database (`AppDatabase.forTesting`), goes through
  first-run admin setup, and checks every nav destination renders —
  run with `flutter test`.

### UI/branding pass

The client asked for a modern, colorful, professional look rather than
the default Flutter/Material scaffolding — this touched every screen:

- `lib/theme/app_theme.dart` / `app_colors.dart` — one Material 3
  `ThemeData` (brand blue `#1E3A8A` / cyan `#06B6D4`, pinned onto
  `ColorScheme.primary`/`secondary` rather than left to
  `ColorScheme.fromSeed`'s own tonal algorithm, which visibly
  desaturates a seed color — see the comment in `app_theme.dart` if
  you're wondering why buttons don't just use `.fromSeed()` output
  directly). Cards, dialogs, inputs, chips, and the nav rail all pick
  this up automatically via component theme defaults — screens
  shouldn't need to hardcode colors outside of `AppColors`' semantic
  status colors (paid/overdue/pending).
- **Inter** (OFL-licensed) is bundled locally under `assets/fonts/` and
  declared in `pubspec.yaml`'s `fonts:` section — deliberately NOT
  `package:google_fonts`, which fetches over the network at runtime by
  default; this is an offline-first desktop app (see "What this is"),
  so typography can't depend on a staff PC having internet the first
  time a screen renders.
- `lib/features/splash/splash_screen.dart` — branded animated splash
  shown for a minimum ~1.1s on launch (see `AuthGate`) while the app
  checks whether any Staff account exists yet.
- `lib/features/dashboard/dashboard_screen.dart` — new landing tab:
  KPI cards (total students, active batches, overdue payments +
  outstanding amount, this month's collected-vs-expected) plus a
  students-by-status breakdown, backed by `DashboardDao`'s aggregate
  queries (`lib/database/daos/dashboard_dao.dart`).
- `lib/app_shell.dart` — the nav rail itself now carries the app's icon
  mark at top and the signed-in user's avatar (+ sign-out menu) pinned
  at the bottom, so branding and "who am I / how do I leave" each have
  exactly one place in the UI instead of being repeated per screen.
- App icon (`windows/runner/resources/app_icon.ico`, and
  `assets/icon/app_icon.png` for in-app use) was regenerated from
  scratch — the default Flutter icon was still in place at handoff.
  It's a programmatically-drawn gradient badge (`assets/icon/` has no
  source file checked in; regenerate by re-running the icon-drawing
  script used during this pass if it ever needs to change — search the
  session history, or just re-draw it, it's a simple Pillow script).

### Auth

Resolves the handoff's open "does v1 need login" question — the client
confirmed yes, an admin should control who else gets access:

- `lib/features/auth/auth_state.dart` — `AuthState` (a
  `ChangeNotifier`, provided at the root next to `AppDatabase`) is the
  whole session model. Deliberately simple: **no persisted session** —
  every app launch requires signing in again, and there's no
  password-reset flow. This is a single-office LOB tool, not a
  multi-tenant product; don't add JWT/refresh-token machinery here.
- **First run**: `AuthState.status` is `needsSetup` when
  `StaffDao.hasAnyStaff()` is false, which routes to
  `SetupAdminScreen` — the very first account created on a PC is
  always `role: 'admin'`, no way around it (only an admin can add more
  staff afterwards, from `StaffScreen`).
- Passwords are bcrypt-hashed with `package:bcrypt`
  (`BCrypt.hashpw`/`checkpw`) — the same scheme
  `legacy/Temidove_Online_PHP` already used for its `users.password`
  column. `BCrypt.checkpw` reads the hash's own minor-version byte
  (`$2a$`/`$2b$`/`$2y$`), so legacy hashes carried over by
  `csv_legacy_importer.dart` verify correctly with no normalization
  needed — confirmed by reading the `bcrypt` package's own source
  rather than assumed.
- **Role gating**: `AuthState.isAdmin` hides the Staff and Import nav
  destinations entirely for a `role: 'staff'` account (see
  `app_shell.dart`) — both because Import can bulk-create/overwrite
  data and because staff credentials shouldn't be staff-editable. This
  was an interpretation call (the client said "admin adds other
  staff," which doesn't by itself say what a non-admin should or
  shouldn't see elsewhere) — **worth confirming with the client**
  whether non-admin staff should also be restricted from anything
  currently left open (Departments/Students/Payments).

### Installer

`.github/workflows/build-windows.yml` used to zip up the raw
`flutter build windows` output (exe + a pile of DLLs + a `data\`
folder) — not something to hand a non-technical client. It now
compiles `windows/installer/temidove_crm.iss` with Inno Setup (ships
preinstalled on `windows-latest` runners; the workflow falls back to a
Chocolatey install if a future runner image ever drops it) into a
single `TemidoveCRM-Setup.exe` — proper Start Menu/Desktop shortcuts,
an uninstaller, and the installer version pulled straight from
`pubspec.yaml` so it can't drift from the app's own version. The
uninstaller deliberately does **not** touch the per-user AppData
SQLite file (see the comment in the `.iss`) — re-installing to upgrade
must never silently wipe live student/payment data.

Deliberately NOT built, by design decision rather than oversight:

1. **Reports/export.** Mentioned in planning as a nice-to-have
   (accountant-facing Excel/PDF export) — not started, not urgent for
   v1.

## Open questions worth raising with the client before finalizing

- What did "offer 1/2/3" actually mean in the old system? It was
  never anything but a fixed 3-option dropdown with no other business
  logic attached — worth confirming it's safe to fold into per-batch
  pricing rather than preserving as a separate concept. (The CSV legacy
  importer currently folds course+level+offer into one synthesized
  Batch per unique combination, priced at the department's standard
  fee — see `csv_legacy_importer.dart` — as a reasonable default given
  this was never resolved.)
- Should non-admin staff be restricted from anything beyond Staff/
  Import (e.g. should they see every student, or only ones assigned to
  them)? Not restricted currently — see "Auth" in "Current state".
- The Excel importer has now been exercised structurally (parse →
  preview → commit) but still only against the one sample file from
  handoff. **Get 2-3 more real filled-in batch trackers from the
  client before trusting it on production data** — this caveat from
  the original handoff still stands.

## Build & run

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

First launch on a fresh install shows a "create administrator account"
screen instead of the app — that's expected, not a bug (see "Auth").

CI builds `TemidoveCRM-Setup.exe` (a single Inno Setup installer, see
"Installer" above) on every push to `main` and publishes it as a
GitHub Release on version tags (`git tag v0.1.0 && git push --tags`) —
see `.github/workflows/build-windows.yml`.
