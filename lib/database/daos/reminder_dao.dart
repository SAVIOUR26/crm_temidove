import 'package:drift/drift.dart';
import '../database.dart';

part 'reminder_dao.g.dart';

@DriftAccessor(tables: [ReminderLog])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);

  /// The most recent reminder sent for a payment, if any — used to warn
  /// staff "already reminded 2 days ago" so nobody double-messages a
  /// student.
  Future<ReminderLogData?> lastForPayment(String paymentId) =>
      (select(reminderLog)
            ..where((r) => r.paymentId.equals(paymentId))
            ..orderBy([(r) => OrderingTerm.desc(r.sentAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> log(ReminderLogCompanion entry) =>
      into(reminderLog).insert(entry);
}
