import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';

/// Landing grid — direct equivalent of the old departments.php page.
/// TODO(claude-code): tapping a card should push a BatchesScreen (list
/// batches for that department, mirroring the old offers.php), which in
/// turn pushes a StudentsScreen filtered to that batch (old clients.php).
/// Neither of those two screens exist yet — this file is the pattern to
/// follow for them.
class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      body: FutureBuilder<List<DepartmentWithBatchCount>>(
        future: db.departmentDao.allWithBatchCount(),
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
            itemBuilder: (context, i) => _DepartmentCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  final DepartmentWithBatchCount item;
  const _DepartmentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          // TODO(claude-code): Navigator.push to a BatchesScreen(
          //   departmentId: item.department.id)
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.department.name,
                style: Theme.of(context).textTheme.titleMedium,
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
