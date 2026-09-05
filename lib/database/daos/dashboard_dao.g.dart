// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_dao.dart';

// ignore_for_file: type=lint
mixin _$DashboardDaoMixin on DatabaseAccessor<AppDatabase> {
  $StaffTable get staff => attachedDatabase.staff;
  $StudentsTable get students => attachedDatabase.students;
  $DepartmentsTable get departments => attachedDatabase.departments;
  $BatchesTable get batches => attachedDatabase.batches;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $PaymentsTable get payments => attachedDatabase.payments;
  DashboardDaoManager get managers => DashboardDaoManager(this);
}

class DashboardDaoManager {
  final _$DashboardDaoMixin _db;
  DashboardDaoManager(this._db);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$DepartmentsTableTableManager get departments =>
      $$DepartmentsTableTableManager(_db.attachedDatabase, _db.departments);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db.attachedDatabase, _db.batches);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}
