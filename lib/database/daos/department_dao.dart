import 'package:drift/drift.dart';
import '../database.dart';

part 'department_dao.g.dart';

@DriftAccessor(tables: [Departments, Batches])
class DepartmentDao extends DatabaseAccessor<AppDatabase>
    with _$DepartmentDaoMixin {
  DepartmentDao(super.db);

  Stream<List<Department>> watchAll() =>
      (select(departments)..where((d) => d.isDeleted.equals(false))).watch();

  /// Departments with a live count of active batches, for the landing
  /// grid — same idea as the old departments.php card view.
  Future<List<DepartmentWithBatchCount>> allWithBatchCount() async {
    final query = select(departments).join([
      leftOuterJoin(
        batches,
        batches.departmentId.equalsExp(departments.id) &
            batches.isDeleted.equals(false),
      ),
    ])
      ..where(departments.isDeleted.equals(false));

    final rows = await query.get();
    final counts = <String, int>{};
    final deptById = <String, Department>{};
    for (final row in rows) {
      final dept = row.readTable(departments);
      deptById[dept.id] = dept;
      final batch = row.readTableOrNull(batches);
      if (batch != null) {
        counts[dept.id] = (counts[dept.id] ?? 0) + 1;
      } else {
        counts.putIfAbsent(dept.id, () => 0);
      }
    }
    return deptById.values
        .map((d) => DepartmentWithBatchCount(d, counts[d.id] ?? 0))
        .toList();
  }

  Future<int> upsert(DepartmentsCompanion entry) =>
      into(departments).insertOnConflictUpdate(entry);
}

class DepartmentWithBatchCount {
  final Department department;
  final int batchCount;
  DepartmentWithBatchCount(this.department, this.batchCount);
}
