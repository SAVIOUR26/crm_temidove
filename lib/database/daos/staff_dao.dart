import 'package:drift/drift.dart';
import '../database.dart';

part 'staff_dao.g.dart';

@DriftAccessor(tables: [Staff])
class StaffDao extends DatabaseAccessor<AppDatabase> with _$StaffDaoMixin {
  StaffDao(super.db);

  Stream<List<StaffData>> watchAll() =>
      (select(staff)..where((s) => s.isDeleted.equals(false))).watch();

  Future<StaffData?> byUsername(String username) =>
      (select(staff)..where((s) => s.username.equals(username)))
          .getSingleOrNull();

  /// True once at least one staff account exists — used to decide whether
  /// to show the first-run "create admin" flow or the ordinary login
  /// screen (see lib/features/auth).
  Future<bool> hasAnyStaff() async {
    final row =
        await (select(staff)..where((s) => s.isDeleted.equals(false))).get();
    return row.isNotEmpty;
  }

  Future<int> upsert(StaffCompanion entry) =>
      into(staff).insertOnConflictUpdate(entry);
}
