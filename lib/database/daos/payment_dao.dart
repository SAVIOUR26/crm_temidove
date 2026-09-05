import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

part 'payment_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Payments, Enrollments, Batches, Students])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  /// Generates the payment schedule for a fresh enrollment: one row per
  /// month of the batch's duration, due on the same day-of-month as the
  /// batch's cycle start. This is the direct replacement for manually
  /// filling in the Excel sheet's Month 1 / Month 2 / Month 3 columns —
  /// call this once, right after an enrollment is created.
  ///
  /// [feeOverride] lets a discounted or custom-arrangement student get a
  /// different amount per installment than the batch's standard fee
  /// (Enrollments.customFee feeds this).
  Future<void> generateScheduleForEnrollment({
    required String enrollmentId,
    required DateTime cycleStart,
    required int durationMonths,
    required double monthlyFee,
    double? feeOverride,
  }) async {
    final amount = feeOverride ?? monthlyFee;
    final rows = List.generate(durationMonths, (i) {
      final dueDate = DateTime(
        cycleStart.year,
        cycleStart.month + i,
        cycleStart.day,
      );
      return PaymentsCompanion.insert(
        id: _uuid.v4(),
        enrollmentId: enrollmentId,
        dueDate: dueDate,
        expectedAmount: amount,
      );
    });

    await batch((b) {
      for (final row in rows) {
        b.insert(payments, row);
      }
    });
  }

  /// Payments due within [withinDays] days, or already overdue — this is
  /// the query behind the "due soon / overdue" dashboard and the
  /// reminder-generation flow. Overdue-ness is computed here rather than
  /// trusted from the stored `status` column, so a payment doesn't need a
  /// background job to "become" overdue — it just is, the moment today
  /// passes its due date.
  Future<List<PaymentWithContext>> dueOrOverdue({int withinDays = 3}) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays));

    final query = select(payments).join([
      innerJoin(enrollments, enrollments.id.equalsExp(payments.enrollmentId)),
      innerJoin(students, students.id.equalsExp(enrollments.studentId)),
      innerJoin(batches, batches.id.equalsExp(enrollments.batchId)),
    ])
      ..where(payments.isDeleted.equals(false) &
          payments.status.equals('paid').not() &
          payments.dueDate.isSmallerOrEqualValue(cutoff))
      ..orderBy([OrderingTerm.asc(payments.dueDate)]);

    final rows = await query.get();
    return rows
        .map((r) => PaymentWithContext(
              payment: r.readTable(payments),
              student: r.readTable(students),
              batch: r.readTable(batches),
            ))
        .toList();
  }

  /// True status accounting for the passage of time — 'overdue' is a
  /// derived state, not something staff set manually.
  static String effectiveStatus(Payment payment) {
    if (payment.status == 'paid') return 'paid';
    if (payment.paidAmount > 0 && payment.paidAmount < payment.expectedAmount) {
      return 'partial';
    }
    if (payment.dueDate.isBefore(DateTime.now())) return 'overdue';
    return 'pending';
  }

  Future<void> recordPayment({
    required String paymentId,
    required double amountPaid,
    DateTime? datePaid,
    String? agentName,
    String? agentPhone,
    String? notes,
  }) async {
    final existing = await (select(payments)
          ..where((p) => p.id.equals(paymentId)))
        .getSingle();
    final newPaid = existing.paidAmount + amountPaid;
    final newStatus = newPaid >= existing.expectedAmount ? 'paid' : 'partial';

    await (update(payments)..where((p) => p.id.equals(paymentId))).write(
      PaymentsCompanion(
        paidAmount: Value(newPaid),
        status: Value(newStatus),
        datePaid: Value(datePaid ?? DateTime.now()),
        // Only overwrite these when this call actually supplies them, so a
        // second (e.g. partial) payment on the same installment doesn't
        // blank out the agent info recorded on the first one.
        agentName: agentName != null ? Value(agentName) : const Value.absent(),
        agentPhone:
            agentPhone != null ? Value(agentPhone) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> upsert(PaymentsCompanion entry) =>
      into(payments).insertOnConflictUpdate(entry);

  /// The full payment schedule for one enrollment, oldest due date first —
  /// feeds the student detail screen's payment history table.
  Stream<List<Payment>> watchForEnrollment(String enrollmentId) =>
      (select(payments)
            ..where((p) =>
                p.enrollmentId.equals(enrollmentId) & p.isDeleted.equals(false))
            ..orderBy([(p) => OrderingTerm.asc(p.dueDate)]))
          .watch();
}

class PaymentWithContext {
  final Payment payment;
  final Student student;
  final BatchData batch;
  PaymentWithContext(
      {required this.payment, required this.student, required this.batch});
}
