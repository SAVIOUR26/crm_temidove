import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../students/batch_students_screen.dart';

const _uuid = Uuid();

/// Batches running within one department — direct equivalent of the old
/// offers.php drill-down (department -> offer/batch -> clients). Batches
/// is the entity the old system never formalized (see /CLAUDE.md).
class BatchesScreen extends StatefulWidget {
  final Department department;
  const BatchesScreen({super.key, required this.department});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM yyyy');

  Future<void> _openBatchForm(AppDatabase db, {BatchData? existing}) async {
    final instructorController =
        TextEditingController(text: existing?.instructorName ?? '');
    final levelController = TextEditingController(text: existing?.level ?? '');
    final feeController =
        TextEditingController(text: existing?.monthlyFee.toString() ?? '');
    final durationController =
        TextEditingController(text: existing?.durationMonths.toString() ?? '3');
    DateTime cycleStart = existing?.cycleStart ?? DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add batch' : 'Edit batch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: instructorController,
                  decoration: const InputDecoration(labelText: 'Instructor'),
                  autofocus: true,
                ),
                TextField(
                  controller: levelController,
                  decoration: const InputDecoration(
                      labelText: 'Level (e.g. Prelevel, Level 1)'),
                ),
                TextField(
                  controller: feeController,
                  decoration:
                      const InputDecoration(labelText: 'Monthly fee (UGX)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: durationController,
                  decoration:
                      const InputDecoration(labelText: 'Duration (months)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            'Cycle start: ${_dateFmt.format(cycleStart)}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: cycleStart,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => cycleStart = picked);
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final fee = double.tryParse(feeController.text);
    if (fee == null) return;

    await db.batchDao.upsert(BatchesCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      departmentId: Value(widget.department.id),
      instructorName: Value(instructorController.text.trim().isEmpty
          ? null
          : instructorController.text.trim()),
      level: Value(levelController.text.trim().isEmpty
          ? null
          : levelController.text.trim()),
      cycleStart: Value(cycleStart),
      durationMonths: Value(int.tryParse(durationController.text) ?? 3),
      monthlyFee: Value(fee),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.department.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBatchForm(db),
        icon: const Icon(Icons.add),
        label: const Text('Add batch'),
      ),
      body: StreamBuilder<List<BatchData>>(
        stream: db.batchDao.watchForDepartment(widget.department.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final batches = snapshot.data!;
          if (batches.isEmpty) {
            return const Center(
              child: Text('No batches yet in this department.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _BatchTile(
              batch: batches[i],
              db: db,
              currency: _currency,
              dateFmt: _dateFmt,
              onEdit: () => _openBatchForm(db, existing: batches[i]),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BatchStudentsScreen(batch: batches[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final BatchData batch;
  final AppDatabase db;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _BatchTile({
    required this.batch,
    required this.db,
    required this.currency,
    required this.dateFmt,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: db.batchDao.enrollmentCount(batch.id),
      builder: (context, snapshot) {
        final count = snapshot.data;
        return ListTile(
          onTap: onTap,
          title: Text([
            if (batch.instructorName != null) batch.instructorName,
            if (batch.level != null) batch.level,
          ].whereType<String>().join(' · ').ifEmpty('Unnamed batch')),
          subtitle: Text(
            '${currency.format(batch.monthlyFee)}/mo · ${batch.durationMonths} months'
            '${batch.cycleStart != null ? " · starts ${dateFmt.format(batch.cycleStart!)}" : ""}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(count == null ? '…' : '$count students'),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _StringOrDefault on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
