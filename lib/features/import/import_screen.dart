import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import 'excel_batch_importer.dart';
import 'excel_import_committer.dart';
import 'csv_legacy_importer.dart';

/// Legacy data import. Two sources (see /CLAUDE.md for the full mapping):
///   1. Excel batch-tracker workbooks (excel_batch_importer.dart) — parsed,
///      previewed, and committed to Batches/Students/Enrollments/Payments
///      below, per sheet, once a department + fee/duration are confirmed.
///   2. The old PHP app's data, exported as CSV per-table (courses, users,
///      registrations) rather than parsed from the raw .sql dump — see
///      csv_legacy_importer.dart for why CSV was chosen over hand-rolling
///      a SQL parser.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<ParsedBatchSheet>? _results;
  String? _fileName;
  bool _loading = false;
  final Set<int> _committed = {};

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
      _committed.clear();
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
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _loading ? null : _pickAndParse,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose an Excel payment tracker (.xlsx)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const CsvLegacyImportDialog(),
                  ),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Import legacy PHP data (CSV)'),
                ),
              ],
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text('Parsed: $_fileName'),
            ],
            const SizedBox(height: 24),
            if (_loading) const CircularProgressIndicator(),
            if (_results != null)
              Expanded(
                child: ListView.separated(
                  itemCount: _results!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _SheetCommitCard(
                    sheet: _results![i],
                    committed: _committed.contains(i),
                    onCommitted: () => setState(() => _committed.add(i)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetCommitCard extends StatefulWidget {
  final ParsedBatchSheet sheet;
  final bool committed;
  final VoidCallback onCommitted;

  const _SheetCommitCard({
    required this.sheet,
    required this.committed,
    required this.onCommitted,
  });

  @override
  State<_SheetCommitCard> createState() => _SheetCommitCardState();
}

class _SheetCommitCardState extends State<_SheetCommitCard> {
  String? _departmentId;
  late final _feeController =
      TextEditingController(text: widget.sheet.monthlyFee?.toStringAsFixed(0) ?? '');
  late final _durationController = TextEditingController(
    text: _maxMonths(widget.sheet).toString(),
  );
  late final _instructorController =
      TextEditingController(text: _guessInstructor(widget.sheet.batchLabel));
  late final _levelController =
      TextEditingController(text: _guessLevel(widget.sheet.batchLabel));

  bool _committing = false;
  ImportCommitResult? _result;

  int _maxMonths(ParsedBatchSheet sheet) {
    var max = 3;
    for (final s in sheet.students) {
      if (s.months.length > max) max = s.months.length;
    }
    return max;
  }

  // "Ruth_Prelevel_Batch_4" -> instructor "Ruth". Best-effort only — see
  // excel_batch_importer.dart's header notes on how inconsistent these
  // sheets are; staff can correct this field before committing.
  String _guessInstructor(String? label) {
    if (label == null) return '';
    final parts = label.split('_');
    return parts.isNotEmpty ? parts.first.trim() : '';
  }

  String _guessLevel(String? label) {
    if (label == null) return '';
    final parts = label.split('_');
    return parts.length > 1 ? parts.skip(1).join(' ').trim() : '';
  }

  Future<void> _commit() async {
    if (_departmentId == null) return;
    final fee = double.tryParse(_feeController.text);
    final duration = int.tryParse(_durationController.text);
    if (fee == null || duration == null) return;

    setState(() => _committing = true);
    final db = context.read<AppDatabase>();
    final committer = ExcelImportCommitter(db);
    final result = await committer.commit(
      sheet: widget.sheet,
      departmentId: _departmentId!,
      monthlyFee: fee,
      durationMonths: duration,
      instructorName:
          _instructorController.text.trim().isEmpty ? null : _instructorController.text.trim(),
      level: _levelController.text.trim().isEmpty ? null : _levelController.text.trim(),
    );
    setState(() {
      _committing = false;
      _result = result;
    });
    widget.onCommitted();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final db = context.read<AppDatabase>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sheet.sheetName, style: Theme.of(context).textTheme.titleMedium),
            Text('Batch label: ${sheet.batchLabel ?? "unknown"} · '
                '${sheet.students.length} student rows parsed'),
            for (final w in sheet.warnings)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('⚠ $w', style: TextStyle(color: Colors.orange.shade800)),
              ),
            const Divider(height: 24),
            if (_result != null)
              _CommitSummary(result: _result!)
            else if (sheet.students.isEmpty)
              const Text('Nothing to commit — no student rows were parsed.')
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StreamBuilder<List<Department>>(
                      stream: db.departmentDao.watchAll(),
                      builder: (context, snapshot) {
                        final departments = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: _departmentId,
                          decoration: const InputDecoration(labelText: 'Department'),
                          items: departments
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _departmentId = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _instructorController,
                      decoration: const InputDecoration(labelText: 'Instructor'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _levelController,
                      decoration: const InputDecoration(labelText: 'Level'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _feeController,
                      decoration: const InputDecoration(labelText: 'Monthly fee (UGX)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      decoration: const InputDecoration(labelText: 'Duration (months)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: (_committing || _departmentId == null) ? null : _commit,
                  icon: _committing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Commit to database'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommitSummary extends StatelessWidget {
  final ImportCommitResult result;
  const _CommitSummary({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Committed: ${result.studentsCreated} new students, '
              '${result.studentsMatched} matched to existing, '
              '${result.paymentsCreated} payments recorded.',
            ),
          ],
        ),
        for (final w in result.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⚠ $w', style: TextStyle(color: Colors.orange.shade800)),
          ),
      ],
    );
  }
}
