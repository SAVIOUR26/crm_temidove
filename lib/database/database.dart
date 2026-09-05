// Temidove CRM — core database schema (Drift / SQLite).
//
// Design notes (see /CLAUDE.md for the full rationale):
//  - Every table uses a TEXT (uuid) primary key, not autoincrement ints.
//    This is what lets a future sync layer (Laravel API on the existing
//    Contabo VPS) merge records created offline on different staff PCs
//    without id collisions.
//  - Every table carries createdAt / updatedAt / isDeleted. updatedAt
//    drives conflict resolution during sync; isDeleted is a soft delete
//    so deletions can also replicate instead of just disappearing locally.
//  - `Batches` is the entity that didn't exist in the old PHP app — it
//    formalizes what "offer 1/2/3" and the Excel filenames
//    ("Ruth_Prelevel_Batch_4") were both informally encoding: an
//    instructor + level + start date + fee running as one cohort.
//  - `Payments` replaces the old Excel's fixed 3 month columns with an
//    open-ended schedule generated per enrollment (see
//    lib/features/payments for the generation logic), so a batch can run
//    3 months or 12 without a schema change.
//
// After editing this file, regenerate the generated code with:
//   dart run build_runner build --delete-conflicting-outputs

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/department_dao.dart';
import 'daos/batch_dao.dart';
import 'daos/staff_dao.dart';
import 'daos/student_dao.dart';
import 'daos/enrollment_dao.dart';
import 'daos/payment_dao.dart';
import 'daos/reminder_dao.dart';
import 'daos/dashboard_dao.dart';

// Re-export the DAOs' small result-holder classes (DepartmentWithBatchCount,
// PaymentWithContext, etc.) so screens only need `import 'database.dart'`
// rather than reaching into lib/database/daos/ directly.
export 'daos/department_dao.dart';
export 'daos/batch_dao.dart';
export 'daos/staff_dao.dart';
export 'daos/student_dao.dart';
export 'daos/enrollment_dao.dart';
export 'daos/payment_dao.dart';
export 'daos/reminder_dao.dart';
export 'daos/dashboard_dao.dart';

part 'database.g.dart';

/// Shared columns every table gets. Mix this in rather than retyping
/// id/createdAt/updatedAt/isDeleted on every table below.
mixin SyncableColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// Courses on offer — "English Language", "Accounting", etc.
/// Maps 1:1 from the old PHP `courses` table.
@DataClassName('Department')
class Departments extends Table with SyncableColumns {
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().nullable()();
  RealColumn get standardPrice => real().withDefault(const Constant(0))();
  IntColumn get durationWeeks => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A running cohort within a department — an instructor teaching a level
/// to a group of students on a shared fee/schedule. This is the entity
/// the old system never had a name for.
// Named BatchData (not Batch) to avoid colliding with drift's own Batch
// class (the batch-write helper used in DAOs' `batch((b) { ... })` calls).
@DataClassName('BatchData')
class Batches extends Table with SyncableColumns {
  TextColumn get departmentId => text().references(Departments, #id)();
  TextColumn get instructorName => text().nullable()();
  // Free text on purpose — the PHP app hardcoded 6 levels as an ENUM,
  // which is exactly the kind of thing that breaks the first time a new
  // course needs different levels. Validate in the UI layer instead.
  TextColumn get level => text().nullable()();
  DateTimeColumn get cycleStart => dateTime().nullable()();
  IntColumn get durationMonths => integer().withDefault(const Constant(3))();
  RealColumn get monthlyFee => real()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Admin/staff users. Maps 1:1 from the old PHP `users` table.
@DataClassName('StaffData')
class Staff extends Table with SyncableColumns {
  TextColumn get username => text().withLength(min: 1, max: 50)();
  TextColumn get fullName => text()();
  // 'admin' or 'staff' — kept as free text rather than a Dart enum column
  // so new roles don't require a migration.
  TextColumn get role => text().withDefault(const Constant('staff'))();
  // Store a password HASH only, same as the old app (bcrypt). Never store
  // plaintext. Local-only auth for v1 — revisit when the sync API lands.
  TextColumn get passwordHash => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A prospective or enrolled student — maps from the old PHP
/// `registrations` table, minus the course/level/offer fields (those move
/// to Enrollments, since a student can now touch more than one batch).
@DataClassName('Student')
class Students extends Table with SyncableColumns {
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  // waiting | started | completed | cancelled — same vocabulary as the
  // old dashboard so the mental model carries over for staff.
  TextColumn get status => text().withDefault(const Constant('waiting'))();
  TextColumn get assignedStaffId => text().nullable().references(Staff, #id)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Links a student to a batch. One student can have several enrollments
/// over time (e.g. re-enrolling for a higher level).
@DataClassName('Enrollment')
class Enrollments extends Table with SyncableColumns {
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get batchId => text().references(Batches, #id)();
  // Overrides Batches.monthlyFee for this student only — discounts,
  // late joiners, custom arrangements. Null = use the batch's standard fee.
  RealColumn get customFee => real().nullable()();
  DateTimeColumn get enrolledOn => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get startDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One scheduled payment. Generated automatically when a student enrolls
/// (see PaymentDao.generateScheduleForEnrollment) — this is what replaces
/// the Excel sheet's fixed Month 1 / Month 2 / Month 3 columns.
@DataClassName('Payment')
class Payments extends Table with SyncableColumns {
  TextColumn get enrollmentId => text().references(Enrollments, #id)();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get expectedAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  // pending | paid | partial | overdue — overdue is computed at read time
  // from dueDate vs today rather than trusted as stored state; see
  // PaymentDao.effectiveStatus.
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get datePaid => dateTime().nullable()();
  // Mirrors the Excel tracker's "Agency Name / Agency Phone" columns —
  // the mobile money agent or channel the student paid through.
  TextColumn get agentName => text().nullable()();
  TextColumn get agentPhone => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Records that a payment reminder was sent, and through which channel,
/// so two staff members don't message the same overdue student twice.
@DataClassName('ReminderLogData')
class ReminderLog extends Table with SyncableColumns {
  TextColumn get paymentId => text().references(Payments, #id)();
  DateTimeColumn get sentAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get channel => text().withDefault(const Constant('whatsapp'))();
  TextColumn get sentByStaffId => text().nullable().references(Staff, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Departments,
    Batches,
    Staff,
    Students,
    Enrollments,
    Payments,
    ReminderLog,
  ],
  daos: [
    DepartmentDao,
    BatchDao,
    StaffDao,
    StudentDao,
    EnrollmentDao,
    PaymentDao,
    ReminderDao,
    DashboardDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Lets widget/DAO tests run against an in-memory database instead of a
  // real file on disk — see test/widget_test.dart.
  AppDatabase.forTesting(super.executor);

  // Bump this whenever a table shape changes and add a migration step —
  // see the Drift docs on schema migrations. Don't skip this: this app
  // holds live financial data, silent data loss on upgrade is not
  // acceptable.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // sqlite3_flutter_libs bundles a recent SQLite build and wires it up
    // at build time for Windows/macOS/Linux — no runtime workaround call
    // needed on desktop (that API only exists for old Android versions).
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'temidove_crm.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
