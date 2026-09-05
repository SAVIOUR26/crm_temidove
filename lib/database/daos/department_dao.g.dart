// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'department_dao.dart';

// ignore_for_file: type=lint
mixin _$DepartmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $DepartmentsTable get departments => attachedDatabase.departments;
  $BatchesTable get batches => attachedDatabase.batches;
  DepartmentDaoManager get managers => DepartmentDaoManager(this);
}

class DepartmentDaoManager {
  final _$DepartmentDaoMixin _db;
  DepartmentDaoManager(this._db);
  $$DepartmentsTableTableManager get departments =>
      $$DepartmentsTableTableManager(_db.attachedDatabase, _db.departments);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db.attachedDatabase, _db.batches);
}
