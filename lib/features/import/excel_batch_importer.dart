// Importer for the legacy "Student Payment Tracker" Excel template.
//
// Reverse-engineered from Temidove's actual Sample.xlsx (sheet name
// "Ruth_English_LEVEL 1 8_B_4"). Layout is NOT a plain table — it's a
// hand-built dashboard with merged title rows before the real data
// starts:
//
//   Row 1: workbook title
//   Row 2: "Batch: <name>   |   Payment: <fee> per month   |   ...<period>"
//   Row 5-6: due dates for month 1/2/3 (as a date range string, e.g.
//            "10/4/2026-10/5/2026")
//   Row 8: section headers (STUDENT INFO / MONTH 1 / MONTH 2 / MONTH 3 / NOTES)
//   Row 9: actual column headers
//   Row 10+: one row per student, until a "TOTALS" row ends the table
//   Row 40ish: legend
//
// Column headers repeat per month ("Due Date", "Status", "Date Paid",
// "Agency Name", "Agency No") and are inconsistently spelled between
// sheets ("Agenecy No" vs "Agency No", "Agency Phoe No"), so headers are
// matched fuzzily rather than by fixed column index — don't trust column
// letters to be stable across real files.
//
// TODO(claude-code): this was designed against ONE sample file. Before
// relying on it for a real bulk import, get 3-4 more real (anonymized)
// batch trackers from the client and confirm the header-matching regexes
// below still catch every variant, and that the "TOTALS" sentinel that
// ends the student table is actually consistent across files.

import 'package:excel/excel.dart';

// Note: this importer only parses the spreadsheet into the structures
// below. Turning a confirmed ParsedBatchSheet into actual
// Students/Enrollments/Payments rows (with fresh uuids) is the job of
// ImportPreviewScreen (TODO) — keeping that step separate means the user
// sees and can correct the parse before anything touches the database.

/// One parsed student row, ready to preview before it's committed to the
/// database. Kept deliberately dumb/flat — mapping this into
/// Students/Enrollments/Payments rows happens after the user confirms the
/// preview (see ImportPreviewScreen, still to build).
class ParsedStudentRow {
  final String? name;
  final String? phone;
  final DateTime? startDate;
  final List<ParsedMonthPayment> months;
  final String? notes;

  ParsedStudentRow({
    this.name,
    this.phone,
    this.startDate,
    required this.months,
    this.notes,
  });

  bool get looksEmpty =>
      (name == null || name!.trim().isEmpty) &&
      (phone == null || phone!.trim().isEmpty);
}

class ParsedMonthPayment {
  final int monthIndex; // 1, 2, 3...
  final DateTime? dueDate;
  final String? status; // PAID / PENDING / OVERDUE / PARTIAL, as written
  final DateTime? datePaid;
  final String? agentName;
  final String? agentPhone;

  ParsedMonthPayment({
    required this.monthIndex,
    this.dueDate,
    this.status,
    this.datePaid,
    this.agentName,
    this.agentPhone,
  });
}

class ParsedBatchSheet {
  final String sheetName;
  final String? batchLabel; // from the "Batch: ..." line, e.g. "Ruth_Prelevel_Batch_4"
  final double? monthlyFee; // parsed out of "Payment: 50,000 per month"
  final List<ParsedStudentRow> students;
  final List<String> warnings;

  ParsedBatchSheet({
    required this.sheetName,
    this.batchLabel,
    this.monthlyFee,
    required this.students,
    required this.warnings,
  });
}

class ExcelBatchImporter {
  /// Parses every sheet in the workbook — a client may keep several
  /// batches as separate sheets in one file, or one sheet per file.
  /// Either way, each sheet is independent.
  List<ParsedBatchSheet> parseWorkbook(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    return excel.tables.entries
        .map((entry) => _parseSheet(entry.key, entry.value))
        .toList();
  }

  ParsedBatchSheet _parseSheet(String sheetName, Sheet sheet) {
    final warnings = <String>[];
    final rows = sheet.rows;

    String? batchLabel;
    double? monthlyFee;

    // Row 2 (index 1) typically holds "Batch: X | Payment: Y per month | ..."
    if (rows.length > 1) {
      final line = _rowText(rows[1]);
      final batchMatch = RegExp(r'Batch:\s*([^|]+)').firstMatch(line);
      if (batchMatch != null) batchLabel = batchMatch.group(1)?.trim();

      final feeMatch =
          RegExp(r'Payment:\s*([\d,]+)\s*per month', caseSensitive: false)
              .firstMatch(line);
      if (feeMatch != null) {
        monthlyFee = double.tryParse(feeMatch.group(1)!.replaceAll(',', ''));
      }
    }
    if (batchLabel == null) {
      warnings.add(
          'Could not find a "Batch: ..." line on row 2 — batch name will need to be entered manually.');
    }

    // Find the real header row: the one containing "Student Name" (case
    // insensitive). Don't assume it's row 9 — hand-edited sheets shift.
    int headerRowIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      final text = _rowText(rows[i]).toLowerCase();
      if (text.contains('student name')) {
        headerRowIndex = i;
        break;
      }
    }
    if (headerRowIndex == -1) {
      warnings.add(
          'Could not locate the header row (expected a "Student Name" column) — sheet skipped.');
      return ParsedBatchSheet(
        sheetName: sheetName,
        batchLabel: batchLabel,
        monthlyFee: monthlyFee,
        students: const [],
        warnings: warnings,
      );
    }

    final headers = rows[headerRowIndex]
        .map((c) => (c?.value?.toString() ?? '').trim())
        .toList();
    final colIndex = _buildColumnIndex(headers);

    final students = <ParsedStudentRow>[];
    for (var i = headerRowIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final firstCell = (row.isNotEmpty ? row[0]?.value?.toString() : null) ?? '';
      if (firstCell.trim().toUpperCase() == 'TOTALS') break; // end of table
      if (firstCell.trim().toUpperCase() == 'LEGEND:') break;

      final parsed = _parseStudentRow(row, colIndex);
      if (!parsed.looksEmpty) students.add(parsed);
    }

    if (students.isEmpty) {
      warnings.add(
          'No student rows with a name/phone found — this sheet may be a blank template rather than filled data.');
    }

    return ParsedBatchSheet(
      sheetName: sheetName,
      batchLabel: batchLabel,
      monthlyFee: monthlyFee,
      students: students,
      warnings: warnings,
    );
  }

  /// Maps header text to a column index, matching loosely because the
  /// real files are not consistently spelled ("Agenecy No", "Agency Phoe
  /// No" were both seen in the one sample already).
  Map<String, List<int>> _buildColumnIndex(List<String> headers) {
    final result = <String, List<int>>{
      'name': [],
      'phone': [],
      'start_date': [],
      'due_date': [],
      'status': [],
      'date_paid': [],
      'agent_name': [],
      'agent_phone': [],
      'notes': [],
    };

    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (h.contains('student name') || h == 'name') {
        result['name']!.add(i);
      } else if (h.contains('phone')) {
        // "Agency Phone/Phoe No" also contains "phon(e)" — check agency
        // first so it doesn't get miscategorized as the student's phone.
        if (h.contains('agenc')) {
          result['agent_phone']!.add(i);
        } else {
          result['phone']!.add(i);
        }
      } else if (h.contains('agenc') && (h.contains('no') || h.contains('number'))) {
        result['agent_phone']!.add(i);
      } else if (h.contains('agenc')) {
        result['agent_name']!.add(i);
      } else if (h.contains('start date')) {
        result['start_date']!.add(i);
      } else if (h.contains('due date')) {
        result['due_date']!.add(i);
      } else if (h == 'status') {
        result['status']!.add(i);
      } else if (h.contains('date paid')) {
        result['date_paid']!.add(i);
      } else if (h.contains('note')) {
        result['notes']!.add(i);
      }
    }
    return result;
  }

  ParsedStudentRow _parseStudentRow(
      List<Data?> row, Map<String, List<int>> colIndex) {
    String? cellStr(int? idx) {
      if (idx == null || idx >= row.length) return null;
      final v = row[idx]?.value;
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    DateTime? cellDate(int? idx) {
      final s = cellStr(idx);
      if (s == null) return null;
      return DateTime.tryParse(s) ?? _tryParseSlashDate(s);
    }

    final months = <ParsedMonthPayment>[];
    // due_date/status/date_paid/agent_* columns repeat 3x across the row
    // (one block per month) — group them positionally by how many "due
    // date" columns exist rather than assuming exactly 3.
    final dueDateCols = colIndex['due_date']!;
    for (var m = 0; m < dueDateCols.length; m++) {
      final dueCol = dueDateCols[m];
      // Everything else for this month is the nearest matching column
      // AFTER this due-date column and BEFORE the next one.
      final nextBoundary =
          m + 1 < dueDateCols.length ? dueDateCols[m + 1] : row.length;

      int? findInRange(List<int> candidates) {
        final matches =
            candidates.where((c) => c > dueCol && c < nextBoundary);
        return matches.isEmpty ? null : matches.first;
      }

      months.add(ParsedMonthPayment(
        monthIndex: m + 1,
        dueDate: cellDate(dueCol),
        status: cellStr(findInRange(colIndex['status']!)),
        datePaid: cellDate(findInRange(colIndex['date_paid']!)),
        agentName: cellStr(findInRange(colIndex['agent_name']!)),
        agentPhone: cellStr(findInRange(colIndex['agent_phone']!)),
      ));
    }

    return ParsedStudentRow(
      name: cellStr(colIndex['name']!.isNotEmpty ? colIndex['name']![0] : null),
      phone: cellStr(colIndex['phone']!.isNotEmpty ? colIndex['phone']![0] : null),
      startDate: cellDate(
          colIndex['start_date']!.isNotEmpty ? colIndex['start_date']![0] : null),
      months: months,
      notes: cellStr(colIndex['notes']!.isNotEmpty ? colIndex['notes']![0] : null),
    );
  }

  String _rowText(List<Data?> row) =>
      row.map((c) => c?.value?.toString() ?? '').join(' ');

  DateTime? _tryParseSlashDate(String s) {
    // Handles "10/4/2026" style dates, and takes the first half of a
    // range like "10/4/2026-10/5/2026".
    final first = s.split('-').first.trim();
    final parts = first.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
