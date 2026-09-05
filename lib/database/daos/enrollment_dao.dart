import 'package:drift/drift.dart';
import '../database.dart';

part 'enrollment_dao.g.dart';

@DriftAccessor(tables: [Enrollments, Students, Batches, Departments])
class EnrollmentDao extends DatabaseAccessor<AppDatabase>
    with _$EnrollmentDaoMixin {
  EnrollmentDao(super.db);

  Future<int> upsert(EnrollmentsCompanion entry) =>
      into(enrollments).insertOnConflictUpdate(entry);

  Future<Enrollment?> byId(String id) =>
      (select(enrollments)..where((e) => e.id.equals(id))).getSingleOrNull();

  /// Every enrollment for a batch, with the enrolled student attached —
  /// the old clients.php list for a department+offer combination.
  Stream<List<EnrollmentWithStudent>> watchForBatch(String batchId) {
    final query = select(enrollments).join([
      innerJoin(students, students.id.equalsExp(enrollments.studentId)),
    ])
      ..where(enrollments.batchId.equals(batchId) &
          enrollments.isDeleted.equals(false) &
          students.isDeleted.equals(false));
    return query.watch().map((rows) => rows
        .map((r) => EnrollmentWithStudent(
              enrollment: r.readTable(enrollments),
              student: r.readTable(students),
            ))
        .toList());
  }

  /// Every enrollment for a student, with batch + department attached —
  /// feeds the student detail screen's enrollment history.
  Stream<List<EnrollmentWithBatch>> watchForStudent(String studentId) {
    final query = select(enrollments).join([
      innerJoin(batches, batches.id.equalsExp(enrollments.batchId)),
      innerJoin(departments, departments.id.equalsExp(batches.departmentId)),
    ])
      ..where(enrollments.studentId.equals(studentId) &
          enrollments.isDeleted.equals(false))
      ..orderBy([OrderingTerm.desc(enrollments.enrolledOn)]);
    return query.watch().map((rows) => rows
        .map((r) => EnrollmentWithBatch(
              enrollment: r.readTable(enrollments),
              batch: r.readTable(batches),
              department: r.readTable(departments),
            ))
        .toList());
  }
}

class EnrollmentWithStudent {
  final Enrollment enrollment;
  final Student student;
  EnrollmentWithStudent({required this.enrollment, required this.student});
}

class EnrollmentWithBatch {
  final Enrollment enrollment;
  final BatchData batch;
  final Department department;
  EnrollmentWithBatch(
      {required this.enrollment, required this.batch, required this.department});
}
