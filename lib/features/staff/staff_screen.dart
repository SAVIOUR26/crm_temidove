import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../theme/app_colors.dart';

const _uuid = Uuid();
const _roles = ['staff', 'admin'];

/// Staff/instructor roster and credential management. Reachable only by
/// an admin (gated in app_shell.dart) — this is the screen that resolves
/// the client's "admin adds other staff" ask: every account created here
/// gets a bcrypt-hashed password so it can sign in via
/// lib/features/auth/login_screen.dart.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _openStaffForm(
    BuildContext context,
    AppDatabase db, {
    StaffData? existing,
  }) async {
    final fullNameController =
        TextEditingController(text: existing?.fullName ?? '');
    final usernameController =
        TextEditingController(text: existing?.username ?? '');
    final passwordController = TextEditingController();
    String role = existing?.role ?? 'staff';
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add staff' : 'Edit staff'),
          content: SingleChildScrollView(
            child: Column(
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
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? 'Password'
                        : 'New password (leave blank to keep current)',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (existing == null && passwordController.text.length < 6) {
                  setDialogState(
                      () => error = 'Password must be at least 6 characters.');
                  return;
                }
                if (passwordController.text.isNotEmpty &&
                    passwordController.text.length < 6) {
                  setDialogState(
                      () => error = 'Password must be at least 6 characters.');
                  return;
                }
                Navigator.pop(context, true);
              },
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

    final newPassword = passwordController.text;
    await db.staffDao.upsert(StaffCompanion(
      id: Value(existing?.id ?? _uuid.v4()),
      fullName: Value(fullNameController.text.trim()),
      username: Value(usernameController.text.trim()),
      role: Value(role),
      passwordHash: newPassword.isEmpty
          ? const Value.absent()
          : Value(BCrypt.hashpw(newPassword, BCrypt.gensalt())),
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
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.primaryBlue.withValues(alpha: 0.12),
                  child: Text(
                    s.fullName.isEmpty ? '?' : s.fullName[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700),
                  ),
                ),
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
