import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';

/// Equivalent of dashboard.php's registration table: search + status
/// filter over all students. TODO(claude-code): this is a stub — wire up
/// StudentDao.search(), add the status filter chips (waiting / started /
/// completed / cancelled) and a detail view per student showing their
/// enrollments and payment history (StudentDao + PaymentDao joined by
/// enrollment).
class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: StreamBuilder<List<Student>>(
        stream: db.select(db.students).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final students = snapshot.data!.where((s) => !s.isDeleted).toList();
          if (students.isEmpty) {
            return const Center(
              child: Text('No students yet — import legacy data or add one.'),
            );
          }
          return ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = students[i];
              return ListTile(
                title: Text('${s.firstName} ${s.lastName}'),
                subtitle: Text(s.phone),
                trailing: Chip(label: Text(s.status)),
                onTap: () {
                  // TODO(claude-code): push a StudentDetailScreen(studentId: s.id)
                },
              );
            },
          );
        },
      ),
    );
  }
}
