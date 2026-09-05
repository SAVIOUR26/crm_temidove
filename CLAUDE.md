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

The v1 feature set described below is built and wired end-to-end. What
exists:

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
- App shell with 5-tab navigation (Payments due / Departments /
  Students / Staff / Import).
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
- Staff screen: simple roster CRUD (full name/username/role) — this is
  NOT a login screen, see the auth note below.
- Payments dashboard: full due/overdue list with working
  one-tap-reminder and one-tap "Record payment".
- Windows/Linux platform scaffolding (`windows/`, generated via
  `flutter create`) — this was **missing entirely** at handoff, which
  meant `.github/workflows/build-windows.yml`'s `flutter build windows`
  step could never have succeeded. If a build platform folder ever goes
  missing again (e.g. after a bad merge), regenerate it with
  `flutter create --platforms=windows --org com.temidove --project-name temidove_crm .`
  — it only fills in missing platform files, it won't touch `lib/`.
- A widget smoke test (`test/widget_test.dart`) boots the real app shell
  against an in-memory database (`AppDatabase.forTesting`) and checks
  all 5 nav destinations render — run with `flutter test`.

Deliberately NOT built, by design decision rather than oversight:

1. **Auth / login screen.** `Staff.passwordHash` exists in the schema
   and the CSV importer carries over the old app's bcrypt hashes
   as-is (never decoded, never re-hashed) so they're preserved if this
   is revisited — but no login screen or session handling exists. This
   was an open question at handoff ("does v1 need login given each
   staff PC has its own local database?") and nothing since has settled
   it either way — **still confirm with the client before shipping**.
2. **Reports/export.** Mentioned in planning as a nice-to-have
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
- Does v1 need a login screen at all, given each staff PC will (for
  now) have its own local database? Still unresolved — see "Current
  state" above.
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

CI builds a release zip on every push to `main` and publishes a
GitHub Release on version tags (`git tag v0.1.0 && git push --tags`) —
see `.github/workflows/build-windows.yml`.
