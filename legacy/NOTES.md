# Legacy system analysis

Two systems this app replaces, both belonging to Temidove Smart
Solutions. Source files for both are in this folder.

## 1. `Temidove_Online_PHP/` — the old inquiry/enrollment dashboard

Vanilla PHP + MySQL, WAMP-only, no external dependencies. Drill-down
navigation: **Departments** (courses) → **Offers** (fixed "offer 1/2/3"
pricing tiers) → **Clients** (student registrations for that
department+offer). See `temidove_database.sql` for the schema actually
shipped, and `dashboard.php` / `clients.php` for the richer live query
logic (level + offer fields exist in code but not in the README's
documented schema — the README undersells what's actually implemented).

Key tables → new schema mapping:

| Old (PHP/MySQL)              | New (`lib/database/database.dart`)      |
|-------------------------------|------------------------------------------|
| `courses`                     | `Departments`                            |
| `users`                       | `Staff`                                  |
| `registrations`                | `Students` (+ one `Enrollments` row)     |
| `registrations.course_id`      | `Enrollments.batchId` → `Batches.departmentId` |
| `registrations.offer` (offer 1/2/3) | folded into `Batches` — see below   |
| `registrations.level`          | `Batches.level` (kept as free text, not an ENUM — the old 6-value ENUM was already brittle) |
| `registrations.status`         | `Students.status`                        |
| `registrations.assigned_to`    | `Students.assignedStaffId`               |
| `registrations.notes`          | `Students.notes`                         |

No payment/fee tracking exists anywhere in this system — that's the
Excel tracker's job (below), and the whole reason the two tools were
disconnected.

## 2. `Sample_Payment_Tracker.xlsx` — the Excel payment tracker

One workbook per batch (sheet name in this sample:
`Ruth_English_LEVEL 1 8_B_4`). Hand-built as a 3-month payment reminder
dashboard, NOT a plain table — see
`lib/features/import/excel_batch_importer.dart` for the exact row/column
layout this was reverse-engineered from.

This is where "batch" as a real concept comes from: the sheet is titled
with an instructor + level + batch number (`Ruth_Prelevel_Batch_4`) that
the PHP app has no equivalent for. That's why `Batches` is a new table
rather than a straight port of anything in the old schema — it's
formalizing something Temidove was already doing by hand, one Excel
filename at a time.

The sample file's student-identity columns (name, phone) are blank —
this looks like an anonymized/template copy, not real production data.
The payment status grid (27 rows, PAID/PENDING per month) IS populated,
so the parser was designed and should be tested against that real
structure, but **get 2-3 more real filled-in batch files from the
client before trusting the importer on production data** — one sample
isn't enough to be confident every header variant is caught.

## The core design decision

The old PHP app organizes by "offer 1/2/3" (a pricing tier with no other
meaning attached). The Excel trackers organize by named batch
(instructor + level + cycle). These don't reconcile as-is. The new
schema resolves this by making `Batches` the real unit — instructor,
level, start date, monthly fee, duration all live there — and offer
1/2/3 either becomes a per-batch pricing variant (if that distinction
still matters to the client) or disappears in favor of `Enrollments.customFee`
for one-off arrangements. **Worth confirming with the client what "offer
1/2/3" actually meant to them before finalizing this** — it wasn't fully
resolved in planning, since it never came up as anything more than a
fixed 3-option dropdown in the old form.
