import 'package:drift/drift.dart';
import '../database.dart';

part 'batch_dao.g.dart';

@DriftAccessor(tables: [Batches, Enrollments])
class BatchDao extends DatabaseAccessor<AppDatabase> with _$BatchDaoMixin {
  BatchDao(super.db);

  Stream<List<BatchData>> watchForDepartment(String departmentId) =>
      (select(batches)
            ..where((b) =>
                b.departmentId.equals(departmentId) &
                b.isDeleted.equals(false)))
          .watch();

  Future<int> upsert(BatchesCompanion entry) =>
      into(batches).insertOnConflictUpdate(entry);

  /// How many active enrollments a batch currently has — shown on the
  /// batch card, equivalent to the old offers.php client counts.
  Future<int> enrollmentCount(String batchId) async {
    final count = countAll(
        filter: enrollments.batchId.equals(batchId) &
            enrollments.isDeleted.equals(false));
    final row =
        await (selectOnly(enrollments)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
