import 'package:drift/drift.dart';
import '../database.dart';

part 'student_dao.g.dart';

@DriftAccessor(tables: [Students, Enrollments, Batches, Departments, Staff])
class StudentDao extends DatabaseAccessor<AppDatabase> with _$StudentDaoMixin {
  StudentDao(super.db);

  /// Students enrolled in a given batch — this is what clients.php used
  /// to show for a department + offer combination.
  Stream<List<Student>> watchForBatch(String batchId) {
    final query = select(students).join([
      innerJoin(enrollments, enrollments.studentId.equalsExp(students.id)),
    ])
      ..where(enrollments.batchId.equals(batchId) &
          students.isDeleted.equals(false) &
          enrollments.isDeleted.equals(false));
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(students)).toList());
  }

  /// Dashboard search/filter — mirrors dashboard.php's search box
  /// (name/email/phone) plus status and department filters.
  Future<List<Student>> search({
    String? term,
    String? status,
    String? departmentId,
  }) async {
    final query = select(students).join([
      leftOuterJoin(enrollments, enrollments.studentId.equalsExp(students.id)),
      leftOuterJoin(batches, batches.id.equalsExp(enrollments.batchId)),
    ])
      ..where(students.isDeleted.equals(false));

    if (term != null && term.isNotEmpty) {
      query.where(students.firstName.contains(term) |
          students.lastName.contains(term) |
          students.phone.contains(term) |
          students.email.contains(term));
    }
    if (status != null && status.isNotEmpty) {
      query.where(students.status.equals(status));
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      query.where(batches.departmentId.equals(departmentId));
    }

    final rows = await query.get();
    final seen = <String>{};
    final result = <Student>[];
    for (final r in rows) {
      final s = r.readTable(students);
      if (seen.add(s.id)) result.add(s);
    }
    return result;
  }

  /// Exact phone match, used by the batch-tracker importer to avoid
  /// creating a duplicate Student row for someone already in the system.
  Future<Student?> findByPhone(String phone) => (select(students)
        ..where((s) => s.phone.equals(phone) & s.isDeleted.equals(false)))
      .getSingleOrNull();

  Stream<Student?> watchById(String id) =>
      (select(students)..where((s) => s.id.equals(id))).watchSingleOrNull();

  Future<int> upsert(StudentsCompanion entry) =>
      into(students).insertOnConflictUpdate(entry);

  Future<void> updateStatus(String studentId, String newStatus) =>
      (update(students)..where((s) => s.id.equals(studentId))).write(
        StudentsCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateNotes(String studentId, String? notes) =>
      (update(students)..where((s) => s.id.equals(studentId))).write(
        StudentsCompanion(
          notes: Value(notes),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> assignStaff(String studentId, String? staffId) =>
      (update(students)..where((s) => s.id.equals(studentId))).write(
        StudentsCompanion(
          assignedStaffId: Value(staffId),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
