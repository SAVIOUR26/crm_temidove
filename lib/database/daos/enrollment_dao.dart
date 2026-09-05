import 'package:drift/drift.dart';
import '../database.dart';

part 'enrollment_dao.g.dart';

@DriftAccessor(tables: [Enrollments])
class EnrollmentDao extends DatabaseAccessor<AppDatabase>
    with _$EnrollmentDaoMixin {
  EnrollmentDao(super.db);

  Future<int> upsert(EnrollmentsCompanion entry) =>
      into(enrollments).insertOnConflictUpdate(entry);

  Future<Enrollment?> byId(String id) =>
      (select(enrollments)..where((e) => e.id.equals(id))).getSingleOrNull();
}
