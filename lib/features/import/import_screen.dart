import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'excel_batch_importer.dart';

/// Legacy data import. Two sources to handle (see /CLAUDE.md for the full
/// mapping):
///   1. The old PHP app's MySQL dump (temidove_database.sql) — courses,
///      users, registrations. Straightforward relational mapping, not
///      built yet.
///   2. Excel batch-tracker workbooks (excel_batch_importer.dart) — this
///      screen currently wires up ONLY this path, as a parse-and-preview
///      step. It does not yet write anything to the database.
///
/// TODO(claude-code):
///   - Add a "commit to database" step once the preview looks right:
///     for each ParsedStudentRow, create/match a Student, an Enrollment
///     against a Batch (create the Batch from batchLabel/monthlyFee if it
///     doesn't exist yet), then one Payment per ParsedMonthPayment.
///   - Add the MySQL dump import path (a simple .sql table-data parser,
///     or ask the client to export each table as CSV instead — much
///     easier to parse reliably than hand-rolling SQL parsing).
///   - Surface ParsedBatchSheet.warnings prominently — these are the
///     signal that a real-world file didn't match the expected template
///     and needs a human to look at it before committing.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<ParsedBatchSheet>? _results;
  String? _fileName;
  bool _loading = false;

  Future<void> _pickAndParse() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;

    setState(() {
      _loading = true;
      _fileName = picked.files.single.name;
    });

    final importer = ExcelBatchImporter();
    final results = importer.parseWorkbook(picked.files.single.bytes!);

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import legacy data')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _pickAndParse,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose an Excel payment tracker (.xlsx)'),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('Parsed: $_fileName'),
            ],
            const SizedBox(height: 24),
            if (_loading) const CircularProgressIndicator(),
            if (_results != null)
              Expanded(
                child: ListView(
                  children: _results!.map(_buildSheetSummary).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSummary(ParsedBatchSheet sheet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sheet.sheetName,
                style: Theme.of(context).textTheme.titleMedium),
            Text('Batch: ${sheet.batchLabel ?? "unknown"}   '
                'Monthly fee: ${sheet.monthlyFee ?? "unknown"}'),
            Text('${sheet.students.length} student rows parsed'),
            for (final w in sheet.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('⚠ $w',
                    style: TextStyle(color: Colors.orange.shade800)),
              ),
          ],
        ),
      ),
    );
  }
}
