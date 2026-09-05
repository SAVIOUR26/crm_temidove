// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_dao.dart';

// ignore_for_file: type=lint
mixin _$BatchDaoMixin on DatabaseAccessor<AppDatabase> {
  $DepartmentsTable get departments => attachedDatabase.departments;
  $BatchesTable get batches => attachedDatabase.batches;
  $StaffTable get staff => attachedDatabase.staff;
  $StudentsTable get students => attachedDatabase.students;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  BatchDaoManager get managers => BatchDaoManager(this);
}

class BatchDaoManager {
  final _$BatchDaoMixin _db;
  BatchDaoManager(this._db);
  $$DepartmentsTableTableManager get departments =>
      $$DepartmentsTableTableManager(_db.attachedDatabase, _db.departments);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db.attachedDatabase, _db.batches);
  $$StaffTableTableManager get staff =>
      $$StaffTableTableManager(_db.attachedDatabase, _db.staff);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db.attachedDatabase, _db.students);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
}
