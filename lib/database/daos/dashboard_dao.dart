import 'package:drift/drift.dart';
import '../database.dart';

part 'dashboard_dao.g.dart';

/// One-shot aggregate numbers for the dashboard overview tab. Kept as its
/// own DAO (rather than bolted onto StudentDao/PaymentDao) since these
/// queries exist purely to feed KPI cards, not any entity's own CRUD.
@DriftAccessor(tables: [Students, Batches, Departments, Staff, Payments])
class DashboardDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardDaoMixin {
  DashboardDao(super.db);

  Future<DashboardStats> load() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final totalStudents = await _countRows(
      selectOnly(students)
        ..addColumns([students.id.count()])
        ..where(students.isDeleted.equals(false)),
      students.id.count(),
    );
    final activeBatches = await _countRows(
      selectOnly(batches)
        ..addColumns([batches.id.count()])
        ..where(batches.isDeleted.equals(false)),
      batches.id.count(),
    );
    final totalDepartments = await _countRows(
      selectOnly(departments)
        ..addColumns([departments.id.count()])
        ..where(departments.isDeleted.equals(false)),
      departments.id.count(),
    );
    final totalStaff = await _countRows(
      selectOnly(staff)
        ..addColumns([staff.id.count()])
        ..where(staff.isDeleted.equals(false)),
      staff.id.count(),
    );

    final statusCounts = <String, int>{};
    for (final status in ['waiting', 'started', 'completed', 'cancelled']) {
      statusCounts[status] = await _countRows(
        selectOnly(students)
          ..addColumns([students.id.count()])
          ..where(students.isDeleted.equals(false) &
              students.status.equals(status)),
        students.id.count(),
      );
    }

    final overdueQuery = selectOnly(payments)
      ..addColumns([
        payments.id.count(),
        payments.expectedAmount.sum(),
        payments.paidAmount.sum()
      ])
      ..where(payments.isDeleted.equals(false) &
          payments.status.equals('paid').not() &
          payments.dueDate.isSmallerThanValue(now));
    final overdueRow = await overdueQuery.getSingle();
    final overdueCount = overdueRow.read(payments.id.count()) ?? 0;
    final overdueExpected = overdueRow.read(payments.expectedAmount.sum()) ?? 0;
    final overduePaid = overdueRow.read(payments.paidAmount.sum()) ?? 0;

    final monthQuery = selectOnly(payments)
      ..addColumns([payments.expectedAmount.sum(), payments.paidAmount.sum()])
      ..where(payments.isDeleted.equals(false) &
          payments.dueDate.isBiggerOrEqualValue(monthStart) &
          payments.dueDate.isSmallerThanValue(monthEnd));
    final monthRow = await monthQuery.getSingle();
    final monthExpected = monthRow.read(payments.expectedAmount.sum()) ?? 0;
    final monthCollected = monthRow.read(payments.paidAmount.sum()) ?? 0;

    return DashboardStats(
      totalStudents: totalStudents,
      activeBatches: activeBatches,
      totalDepartments: totalDepartments,
      totalStaff: totalStaff,
      studentsByStatus: statusCounts,
      overdueCount: overdueCount,
      overdueOutstanding: overdueExpected - overduePaid,
      monthExpected: monthExpected,
      monthCollected: monthCollected,
    );
  }

  Future<int> _countRows(
    JoinedSelectStatement<HasResultSet, dynamic> query,
    Expression<int> countColumn,
  ) async {
    final row = await query.getSingle();
    return row.read(countColumn) ?? 0;
  }
}

class DashboardStats {
  final int totalStudents;
  final int activeBatches;
  final int totalDepartments;
  final int totalStaff;
  final Map<String, int> studentsByStatus;
  final int overdueCount;
  final double overdueOutstanding;
  final double monthExpected;
  final double monthCollected;

  DashboardStats({
    required this.totalStudents,
    required this.activeBatches,
    required this.totalDepartments,
    required this.totalStaff,
    required this.studentsByStatus,
    required this.overdueCount,
    required this.overdueOutstanding,
    required this.monthExpected,
    required this.monthCollected,
  });

  double get collectionRate =>
      monthExpected <= 0 ? 0 : (monthCollected / monthExpected).clamp(0, 1);
}
