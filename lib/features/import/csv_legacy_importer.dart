// Importer for the old PHP app's data (legacy/Temidove_Online_PHP), taken
// as CSV exports of its three tables (courses, users, registrations)
// rather than parsed from temidove_database.sql directly — see
// /CLAUDE.md's "not built yet" list for why: a hand-rolled SQL parser is
// brittle against a real production dump (multi-row INSERTs, escaped
// quotes, charset quirks), whereas "export each table as CSV from
// phpMyAdmin" is a five-minute ask the client can do themselves, and a
// CSV table has no such parsing ambiguity.
//
// Column names are matched case-insensitively against the original
// MySQL schema (temidove_database.sql) so an unmodified phpMyAdmin CSV
// export just works.
//
// No payment data is created from this import: the old PHP app never
// tracked fees or payments (see legacy/NOTES.md) — that's what the Excel
// batch-tracker importer (excel_import_committer.dart) is for. A
// registration's course+level+offer becomes one synthesized Batch per
// unique (course, level, offer) combination, priced at the department's
// standard fee, purely so Enrollments has something to point at.

import 'package:csv/csv.dart' show CsvToListConverter;
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';

const _uuid = Uuid();

class _CsvTable {
  final List<String> headers;
  final List<List<String>> rows;
  _CsvTable(this.headers, this.rows);

  int? colIndex(List<String> candidates) {
    for (final c in candidates) {
      final i = headers.indexWhere((h) => h.toLowerCase().trim() == c);
      if (i != -1) return i;
    }
    return null;
  }
}

_CsvTable _parseCsv(String content) {
  final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
      .convert(content)
      .map((r) => r.map((c) => c.toString()).toList())
      .where((r) => r.any((c) => c.trim().isNotEmpty))
      .toList();
  if (rows.isEmpty) return _CsvTable(const [], const []);
  return _CsvTable(rows.first, rows.skip(1).toList());
}

class LegacyImportSummary {
  int departmentsCreated = 0;
  int staffCreated = 0;
  int studentsCreated = 0;
  int enrollmentsCreated = 0;
  final List<String> warnings = [];
}

class CsvLegacyImporter {
  final AppDatabase db;
  CsvLegacyImporter(this.db);

  /// Imports courses.csv -> Departments, users.csv -> Staff, and
  /// registrations.csv -> Students + Enrollments, in that order (later
  /// steps need the id maps the earlier ones build). Any of the three CSV
  /// strings may be omitted (empty) if the client only has some of the
  /// tables to hand.
  Future<LegacyImportSummary> commit({
    String? coursesCsv,
    String? usersCsv,
    String? registrationsCsv,
  }) async {
    final summary = LegacyImportSummary();
    final courseIdToDepartmentId = <String, String>{};
    final userIdToStaffId = <String, String>{};
    final departmentStandardFee = <String, double>{};

    await db.transaction(() async {
      if (coursesCsv != null && coursesCsv.trim().isNotEmpty) {
        await _importCourses(
            coursesCsv, courseIdToDepartmentId, departmentStandardFee, summary);
      }
      if (usersCsv != null && usersCsv.trim().isNotEmpty) {
        await _importUsers(usersCsv, userIdToStaffId, summary);
      }
      if (registrationsCsv != null && registrationsCsv.trim().isNotEmpty) {
        await _importRegistrations(
          registrationsCsv,
          courseIdToDepartmentId,
          userIdToStaffId,
          departmentStandardFee,
          summary,
        );
      }
    });

    return summary;
  }

  Future<void> _importCourses(
    String csv,
    Map<String, String> courseIdToDepartmentId,
    Map<String, double> departmentStandardFee,
    LegacyImportSummary summary,
  ) async {
    final table = _parseCsv(csv);
    final idCol = table.colIndex(['id']);
    final nameCol = table.colIndex(['course_name', 'name']);
    final descCol = table.colIndex(['description']);
    final priceCol = table.colIndex(['price', 'standard_price']);
    final weeksCol = table.colIndex(['duration_weeks']);

    if (nameCol == null) {
      summary.warnings.add(
          'courses.csv: no "course_name" column found — skipped entirely.');
      return;
    }

    for (final row in table.rows) {
      final name = _cell(row, nameCol);
      if (name == null || name.isEmpty) continue;
      final id = _uuid.v4();
      final fee = double.tryParse(_cell(row, priceCol) ?? '') ?? 0;
      await db.departmentDao.upsert(DepartmentsCompanion.insert(
        id: id,
        name: name,
        description: Value(_cell(row, descCol)),
        standardPrice: Value(fee),
        durationWeeks: Value(int.tryParse(_cell(row, weeksCol) ?? '')),
      ));
      departmentStandardFee[id] = fee;
      final oldId = _cell(row, idCol);
      if (oldId != null) courseIdToDepartmentId[oldId] = id;
      summary.departmentsCreated++;
    }
  }

  Future<void> _importUsers(
    String csv,
    Map<String, String> userIdToStaffId,
    LegacyImportSummary summary,
  ) async {
    final table = _parseCsv(csv);
    final idCol = table.colIndex(['id']);
    final usernameCol = table.colIndex(['username']);
    final fullNameCol = table.colIndex(['full_name', 'fullname']);
    final roleCol = table.colIndex(['role']);
    final passwordCol = table.colIndex(['password']);

    if (usernameCol == null) {
      summary.warnings.add('users.csv: no "username" column found — skipped entirely.');
      return;
    }

    for (final row in table.rows) {
      final username = _cell(row, usernameCol);
      if (username == null || username.isEmpty) continue;
      final id = _uuid.v4();
      await db.staffDao.upsert(StaffCompanion.insert(
        id: id,
        username: username,
        fullName: _cell(row, fullNameCol) ?? username,
        role: Value(_cell(row, roleCol) ?? 'staff'),
        // Carried over as-is: the old app already stored a bcrypt hash,
        // never plaintext, so this doesn't introduce a new secret at rest
        // — it just preserves it in case a login screen is added later.
        passwordHash: Value(_cell(row, passwordCol)),
      ));
      final oldId = _cell(row, idCol);
      if (oldId != null) userIdToStaffId[oldId] = id;
      summary.staffCreated++;
    }
  }

  Future<void> _importRegistrations(
    String csv,
    Map<String, String> courseIdToDepartmentId,
    Map<String, String> userIdToStaffId,
    Map<String, double> departmentStandardFee,
    LegacyImportSummary summary,
  ) async {
    final table = _parseCsv(csv);
    final firstNameCol = table.colIndex(['first_name']);
    final lastNameCol = table.colIndex(['last_name']);
    final emailCol = table.colIndex(['email']);
    final phoneCol = table.colIndex(['phone']);
    final courseIdCol = table.colIndex(['course_id']);
    final levelCol = table.colIndex(['level']);
    final offerCol = table.colIndex(['offer']);
    final statusCol = table.colIndex(['status']);
    final notesCol = table.colIndex(['notes']);
    final assignedToCol = table.colIndex(['assigned_to']);
    final startDateCol = table.colIndex(['start_date']);

    if (firstNameCol == null || phoneCol == null) {
      summary.warnings.add(
          'registrations.csv: missing "first_name" or "phone" column — skipped entirely.');
      return;
    }

    // One synthesized Batch per unique (course, level, offer) combination
    // seen in this file — see file header comment for why.
    final batchCache = <String, String>{};

    for (final row in table.rows) {
      final firstName = _cell(row, firstNameCol);
      final phone = _cell(row, phoneCol);
      if (firstName == null || firstName.isEmpty) continue;

      final oldCourseId = _cell(row, courseIdCol);
      final departmentId = oldCourseId != null ? courseIdToDepartmentId[oldCourseId] : null;
      if (departmentId == null) {
        summary.warnings.add(
            '$firstName ${_cell(row, lastNameCol) ?? ""}: course_id "$oldCourseId" not found among imported courses — student skipped.');
        continue;
      }

      final level = _cell(row, levelCol);
      final offer = _cell(row, offerCol);
      final batchKey = '$departmentId|${level ?? ""}|${offer ?? ""}';
      var batchId = batchCache[batchKey];
      if (batchId == null) {
        batchId = _uuid.v4();
        await db.batchDao.upsert(BatchesCompanion.insert(
          id: batchId,
          departmentId: departmentId,
          level: Value(level),
          monthlyFee: departmentStandardFee[departmentId] ?? 0,
        ));
        batchCache[batchKey] = batchId;
      }

      final studentId = _uuid.v4();
      final oldAssignedTo = _cell(row, assignedToCol);
      await db.studentDao.upsert(StudentsCompanion.insert(
        id: studentId,
        firstName: firstName,
        lastName: _cell(row, lastNameCol) ?? '',
        phone: phone ?? '',
        email: Value(_cell(row, emailCol)),
        status: Value(_cell(row, statusCol) ?? 'waiting'),
        assignedStaffId:
            Value(oldAssignedTo != null ? userIdToStaffId[oldAssignedTo] : null),
        notes: Value(_cell(row, notesCol)),
      ));
      summary.studentsCreated++;

      await db.enrollmentDao.upsert(EnrollmentsCompanion.insert(
        id: _uuid.v4(),
        studentId: studentId,
        batchId: batchId,
        startDate: Value(_tryParseDate(_cell(row, startDateCol))),
      ));
      summary.enrollmentsCreated++;
    }
  }

  String? _cell(List<String> row, int? index) {
    if (index == null || index >= row.length) return null;
    final v = row[index].trim();
    return v.isEmpty ? null : v;
  }

  DateTime? _tryParseDate(String? s) {
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
}

/// Dialog that lets staff pick up to three CSV files (courses/users/
/// registrations exported from phpMyAdmin) and commits them in order.
class CsvLegacyImportDialog extends StatefulWidget {
  const CsvLegacyImportDialog({super.key});

  @override
  State<CsvLegacyImportDialog> createState() => _CsvLegacyImportDialogState();
}

class _CsvLegacyImportDialogState extends State<CsvLegacyImportDialog> {
  String? _coursesCsv, _usersCsv, _registrationsCsv;
  String? _coursesName, _usersName, _registrationsName;
  bool _importing = false;
  LegacyImportSummary? _summary;

  Future<void> _pick(void Function(String content, String name) onPicked) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    setState(() => onPicked(String.fromCharCodes(file!.bytes!), file.name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import legacy PHP data (CSV)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export courses, users, and registrations as CSV from '
                'phpMyAdmin (or a client tool) and pick them below. Any '
                'file can be left out.',
              ),
              const SizedBox(height: 16),
              if (_summary == null) ...[
                _FilePickRow(
                  label: 'courses.csv',
                  fileName: _coursesName,
                  onPick: () => _pick((c, n) {
                    _coursesCsv = c;
                    _coursesName = n;
                  }),
                ),
                _FilePickRow(
                  label: 'users.csv',
                  fileName: _usersName,
                  onPick: () => _pick((c, n) {
                    _usersCsv = c;
                    _usersName = n;
                  }),
                ),
                _FilePickRow(
                  label: 'registrations.csv',
                  fileName: _registrationsName,
                  onPick: () => _pick((c, n) {
                    _registrationsCsv = c;
                    _registrationsName = n;
                  }),
                ),
              ] else
                _SummaryView(summary: _summary!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_summary == null ? 'Cancel' : 'Close'),
        ),
        if (_summary == null)
          FilledButton(
            onPressed: _importing
                ? null
                : () async {
                    setState(() => _importing = true);
                    final db = context.read<AppDatabase>();
                    final summary = await CsvLegacyImporter(db).commit(
                      coursesCsv: _coursesCsv,
                      usersCsv: _usersCsv,
                      registrationsCsv: _registrationsCsv,
                    );
                    setState(() {
                      _importing = false;
                      _summary = summary;
                    });
                  },
            child: _importing
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Import'),
          ),
      ],
    );
  }
}

class _FilePickRow extends StatelessWidget {
  final String label;
  final String? fileName;
  final VoidCallback onPick;
  const _FilePickRow({required this.label, required this.fileName, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(fileName ?? 'not selected', overflow: TextOverflow.ellipsis)),
          TextButton(onPressed: onPick, child: const Text('Choose')),
        ],
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final LegacyImportSummary summary;
  const _SummaryView({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Departments created: ${summary.departmentsCreated}'),
        Text('Staff created: ${summary.staffCreated}'),
        Text('Students created: ${summary.studentsCreated}'),
        Text('Enrollments created: ${summary.enrollmentsCreated}'),
        for (final w in summary.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⚠ $w', style: TextStyle(color: Colors.orange.shade800)),
          ),
      ],
    );
  }
}
