// Turns a confirmed ParsedBatchSheet (see excel_batch_importer.dart) into
// real Batches/Students/Enrollments/Payments rows. Kept separate from the
// parser so ImportScreen can show the parse preview and let a human pick
// the department + confirm the fee/duration before anything touches the
// database — see the TODO this replaces in import_screen.dart.
//
// Payments are written directly from each ParsedMonthPayment's own due
// date/status/paid info rather than via PaymentDao.generateScheduleForEnrollment,
// because the Excel sheet already has the real (possibly irregular) due
// dates and payment history — regenerating them from a fixed monthly
// cadence would throw that history away.

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import 'excel_batch_importer.dart';

const _uuid = Uuid();

class ImportCommitResult {
  final String batchId;
  int studentsCreated = 0;
  int studentsMatched = 0;
  int paymentsCreated = 0;
  final List<String> warnings = [];

  ImportCommitResult(this.batchId);
}

class ExcelImportCommitter {
  final AppDatabase db;
  ExcelImportCommitter(this.db);

  /// Commits one parsed sheet as a single batch under [departmentId].
  /// [monthlyFee] and [durationMonths] are passed in explicitly (rather
  /// than trusted from the parse) because the sheet's "Payment: X per
  /// month" line isn't always present or reliable — see ImportScreen,
  /// which pre-fills these from the parse but lets staff correct them
  /// before commit.
  Future<ImportCommitResult> commit({
    required ParsedBatchSheet sheet,
    required String departmentId,
    required double monthlyFee,
    required int durationMonths,
    String? instructorName,
    String? level,
  }) async {
    final batchId = _uuid.v4();
    final result = ImportCommitResult(batchId);

    await db.transaction(() async {
      final cycleStart = _earliestFirstDueDate(sheet) ?? DateTime.now();

      await db.batchDao.upsert(BatchesCompanion.insert(
        id: batchId,
        departmentId: departmentId,
        instructorName: Value(instructorName),
        level: Value(level),
        cycleStart: Value(cycleStart),
        durationMonths: Value(durationMonths),
        monthlyFee: monthlyFee,
      ));

      for (final row in sheet.students) {
        if (row.looksEmpty) continue;

        final phone = row.phone;
        Student? existing;
        if (phone != null && phone.isNotEmpty) {
          existing = await db.studentDao.findByPhone(phone);
        }

        String studentId;
        if (existing != null) {
          studentId = existing.id;
          result.studentsMatched++;
        } else {
          studentId = _uuid.v4();
          final nameParts = (row.name ?? 'Unknown').trim().split(RegExp(r'\s+'));
          await db.studentDao.upsert(StudentsCompanion.insert(
            id: studentId,
            firstName: nameParts.first,
            lastName: nameParts.length > 1 ? nameParts.skip(1).join(' ') : '',
            phone: phone ?? '',
            notes: Value(row.notes),
          ));
          result.studentsCreated++;
        }

        final enrollmentId = _uuid.v4();
        await db.enrollmentDao.upsert(EnrollmentsCompanion.insert(
          id: enrollmentId,
          studentId: studentId,
          batchId: batchId,
          startDate: Value(row.startDate ?? cycleStart),
        ));

        for (final month in row.months) {
          if (month.dueDate == null) {
            result.warnings.add(
                '${row.name ?? "A student"}: month ${month.monthIndex} has no due date — skipped.');
            continue;
          }
          final isPaid = month.status?.toUpperCase().contains('PAID') == true &&
              month.status?.toUpperCase().contains('UNPAID') != true;

          await db.paymentDao.upsert(PaymentsCompanion.insert(
            id: _uuid.v4(),
            enrollmentId: enrollmentId,
            dueDate: month.dueDate!,
            expectedAmount: monthlyFee,
            paidAmount: Value(isPaid ? monthlyFee : 0),
            status: Value(isPaid ? 'paid' : 'pending'),
            datePaid: Value(month.datePaid),
            agentName: Value(month.agentName),
            agentPhone: Value(month.agentPhone),
          ));
          result.paymentsCreated++;
        }
      }
    });

    return result;
  }

  DateTime? _earliestFirstDueDate(ParsedBatchSheet sheet) {
    DateTime? earliest;
    for (final row in sheet.students) {
      if (row.months.isEmpty) continue;
      final due = row.months.first.dueDate;
      if (due == null) continue;
      if (earliest == null || due.isBefore(earliest)) earliest = due;
    }
    return earliest;
  }
}
