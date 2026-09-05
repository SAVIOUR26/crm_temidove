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

  Future<int> upsert(StaffCompanion entry) =>
      into(staff).insertOnConflictUpdate(entry);
}
