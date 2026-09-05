import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';

const _uuid = Uuid();
const _roles = ['staff', 'admin'];

/// Staff/instructor roster. Note: this manages the Staff table used for
/// assigning students to a staff member and naming batch instructors —
/// it does NOT include a login screen. Per /CLAUDE.md, whether v1 needs
/// auth at all is still an open question for the client (each staff PC
/// having its own local database may make it unnecessary); passwordHash
/// stays unset here until that's decided.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _openStaffForm(
    BuildContext context,
    AppDatabase db, {
    StaffData? existing,
  }) async {
    final fullNameController = TextEditingController(text: existing?.fullName ?? '');
    final usernameController = TextEditingController(text: existing?.username ?? '');
    String role = existing?.role ?? 'staff';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add staff' : 'Edit staff'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                autofocus: true,
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setDialogState(() => role = v ?? role),
              ),
            ],
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
    if (fullNameController.text.trim().isEmpty ||
        usernameController.text.trim().isEmpty) {
      return;
    }

    await db.staffDao.upsert(StaffCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      fullName: Value(fullNameController.text.trim()),
      username: Value(usernameController.text.trim()),
      role: Value(role),
      updatedAt: Value(DateTime.now()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openStaffForm(context, db),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add staff'),
      ),
      body: StreamBuilder<List<StaffData>>(
        stream: db.staffDao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final staff = snapshot.data!;
          if (staff.isEmpty) {
            return const Center(child: Text('No staff yet — add one.'));
          }
          return ListView.separated(
            itemCount: staff.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = staff[i];
              return ListTile(
                title: Text(s.fullName),
                subtitle: Text('@${s.username}'),
                trailing: Chip(label: Text(s.role)),
                onTap: () => _openStaffForm(context, db, existing: s),
              );
            },
          );
        },
      ),
    );
  }
}
