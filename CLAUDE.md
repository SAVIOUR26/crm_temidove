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

## Current state (as of handoff)

Scaffolded, not finished. What exists:

- Full Drift schema, all 7 tables (`lib/database/database.dart`).
- DAOs for all tables, with the payment-schedule-generation and
  overdue-status logic fully implemented
  (`lib/database/daos/payment_dao.dart` is the one to read most
  carefully — it's the core business logic).
- Reminder service (wa.me link building + send logging).
- Excel batch-tracker importer: parses and previews, does **not** yet
  write to the database (see the TODO in `import_screen.dart` for the
  exact next step).
- App shell with 4-tab navigation (Payments due / Departments /
  Students / Import).
- Departments screen: full grid, matches old `departments.php`.
- Students screen: minimal list, no search/filter UI yet, no detail
  view.
- Payments dashboard: full due/overdue list with working
  one-tap-reminder.

What's NOT built yet — the real remaining work:

1. **MySQL dump importer** — `legacy/Temidove_Online_PHP/temidove_database.sql`
   → `Departments` + `Staff` + `Students`/`Enrollments`. No parser
   exists for this yet. A `.sql` file is annoying to parse reliably;
   consider asking the client to export each table as CSV instead if
   they still have DB access, and writing a CSV importer instead —
   much less brittle than hand-rolling SQL parsing.
2. **Excel importer → database commit step.** The parser
   (`ExcelBatchImporter`) and preview UI (`ImportScreen`) exist; wiring
   a confirmed `ParsedBatchSheet` into actual `Batches` /
   `Enrollments` / `Students` / `Payments` rows does not.
3. **Batches screen and Students-filtered-by-batch screen** — the
   old `offers.php` → `clients.php` drill-down. `DepartmentsScreen`
   has a `TODO` at the tap handler for exactly this.
4. **Student detail view** — enrollments, full payment history, notes,
   staff assignment editing. Old `dashboard.php`'s edit/view modals are
   the reference for what fields matter.
5. **Auth** — `Staff.passwordHash` exists in the schema; no login
   screen or session handling has been built. Decide whether v1 even
   needs a login screen (single-PC-per-staff might not) before
   building it — check with the client if unsure.
6. **Reports/export** — mentioned in planning as a nice-to-have
   (accountant-facing Excel/PDF export) — not started, not urgent for
   v1.

## Open questions worth raising with the client before finalizing

- What did "offer 1/2/3" actually mean in the old system? It was
  never anything but a fixed 3-option dropdown with no other business
  logic attached — worth confirming it's safe to fold into per-batch
  pricing rather than preserving as a separate concept.
- Does v1 need a login screen at all, given each staff PC will (for
  now) have its own local database?

## Build & run

```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
```

CI builds a release zip on every push to `main` and publishes a
GitHub Release on version tags (`git tag v0.1.0 && git push --tags`) —
see `.github/workflows/build-windows.yml`.
