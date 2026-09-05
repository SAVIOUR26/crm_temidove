import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../batches/batches_screen.dart';

const _uuid = Uuid();

/// Landing grid — direct equivalent of the old departments.php page.
/// Tapping a card pushes a [BatchesScreen] (list batches for that
/// department, mirroring the old offers.php), which in turn pushes a
/// students-filtered-by-batch screen (old clients.php).
class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  late Future<List<DepartmentWithBatchCount>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = context.read<AppDatabase>();
    setState(() {
      _future = db.departmentDao.allWithBatchCount();
    });
  }

  Future<void> _openDepartmentForm({Department? existing}) async {
    final db = context.read<AppDatabase>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController =
        TextEditingController(text: existing?.description ?? '');
    final priceController =
        TextEditingController(text: existing?.standardPrice.toString() ?? '0');
    final weeksController =
        TextEditingController(text: existing?.durationWeeks?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add department' : 'Edit department'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: priceController,
                decoration:
                    const InputDecoration(labelText: 'Standard price (UGX)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: weeksController,
                decoration:
                    const InputDecoration(labelText: 'Duration (weeks)'),
                keyboardType: TextInputType.number,
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
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    await db.departmentDao.upsert(DepartmentsCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      name: Value(name),
      description: Value(
          descController.text.trim().isEmpty ? null : descController.text.trim()),
      standardPrice: Value(double.tryParse(priceController.text) ?? 0),
      durationWeeks: Value(int.tryParse(weeksController.text)),
      updatedAt: Value(DateTime.now()),
    ));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDepartmentForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add department'),
      ),
      body: FutureBuilder<List<DepartmentWithBatchCount>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('No departments yet — import legacy data or add one.'),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _DepartmentCard(
              item: items[i],
              onEdit: () => _openDepartmentForm(existing: items[i].department),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BatchesScreen(department: items[i].department),
                  ),
                );
                _reload();
              },
            ),
          );
        },
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final DepartmentWithBatchCount item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _DepartmentCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.department.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${item.batchCount}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('active batches'),
            ],
          ),
        ),
      ),
    );
  }
}
