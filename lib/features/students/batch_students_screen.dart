import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import 'student_detail_screen.dart';

const _uuid = Uuid();

/// Students enrolled in one batch — direct equivalent of the old
/// clients.php list for a department+offer combination.
class BatchStudentsScreen extends StatefulWidget {
  final BatchData batch;
  const BatchStudentsScreen({super.key, required this.batch});

  @override
  State<BatchStudentsScreen> createState() => _BatchStudentsScreenState();
}

class _BatchStudentsScreenState extends State<BatchStudentsScreen> {
  Future<void> _enrollStudent(AppDatabase db) async {
    final result = await showDialog<_EnrollFormResult>(
      context: context,
      builder: (context) => _EnrollStudentDialog(db: db, batch: widget.batch),
    );
    if (result == null) return;

    String studentId;
    if (result.existingStudent != null) {
      studentId = result.existingStudent!.id;
    } else {
      studentId = _uuid.v4();
      await db.studentDao.upsert(StudentsCompanion.insert(
        id: studentId,
        firstName: result.firstName!,
        lastName: result.lastName!,
        phone: result.phone!,
        email: Value(result.email),
      ));
    }

    final enrollmentId = _uuid.v4();
    final startDate = widget.batch.cycleStart ?? DateTime.now();
    await db.enrollmentDao.upsert(EnrollmentsCompanion.insert(
      id: enrollmentId,
      studentId: studentId,
      batchId: widget.batch.id,
      customFee: Value(result.customFee),
      startDate: Value(startDate),
    ));

    await db.paymentDao.generateScheduleForEnrollment(
      enrollmentId: enrollmentId,
      cycleStart: startDate,
      durationMonths: widget.batch.durationMonths,
      monthlyFee: widget.batch.monthlyFee,
      feeOverride: result.customFee,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        title: Text([widget.batch.instructorName, widget.batch.level]
            .whereType<String>()
            .join(' · ')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _enrollStudent(db),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Enroll student'),
      ),
      body: StreamBuilder<List<EnrollmentWithStudent>>(
        stream: db.enrollmentDao.watchForBatch(widget.batch.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No students enrolled yet.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final row = rows[i];
              return ListTile(
                title: Text('${row.student.firstName} ${row.student.lastName}'),
                subtitle: Text(row.student.phone),
                trailing: Chip(label: Text(row.student.status)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentDetailScreen(studentId: row.student.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EnrollFormResult {
  final Student? existingStudent;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final double? customFee;

  _EnrollFormResult.existing(this.existingStudent, {this.customFee})
      : firstName = null,
        lastName = null,
        phone = null,
        email = null;

  _EnrollFormResult.newStudent({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.customFee,
  }) : existingStudent = null;
}

class _EnrollStudentDialog extends StatefulWidget {
  final AppDatabase db;
  final BatchData batch;
  const _EnrollStudentDialog({required this.db, required this.batch});

  @override
  State<_EnrollStudentDialog> createState() => _EnrollStudentDialogState();
}

class _EnrollStudentDialogState extends State<_EnrollStudentDialog> {
  bool _isNewStudent = true;
  Student? _selectedExisting;
  List<Student> _searchResults = [];

  final _searchController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _customFeeController = TextEditingController();

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await widget.db.studentDao.search(term: term);
    setState(() => _searchResults = results);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enroll student'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('New student')),
                  ButtonSegment(value: false, label: Text('Existing student')),
                ],
                selected: {_isNewStudent},
                onSelectionChanged: (s) => setState(() => _isNewStudent = s.first),
              ),
              const SizedBox(height: 12),
              if (_isNewStudent) ...[
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                ),
              ] else ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by name or phone',
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: _search,
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, i) {
                      final s = _searchResults[i];
                      final selected = _selectedExisting?.id == s.id;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        title: Text('${s.firstName} ${s.lastName}'),
                        subtitle: Text(s.phone),
                        trailing: selected ? const Icon(Icons.check_circle) : null,
                        onTap: () => setState(() => _selectedExisting = s),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _customFeeController,
                decoration: InputDecoration(
                  labelText:
                      'Custom monthly fee (optional, default ${widget.batch.monthlyFee})',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final customFee = double.tryParse(_customFeeController.text);
            if (_isNewStudent) {
              if (_firstNameController.text.trim().isEmpty ||
                  _lastNameController.text.trim().isEmpty ||
                  _phoneController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                _EnrollFormResult.newStudent(
                  firstName: _firstNameController.text.trim(),
                  lastName: _lastNameController.text.trim(),
                  phone: _phoneController.text.trim(),
                  email: _emailController.text.trim().isEmpty
                      ? null
                      : _emailController.text.trim(),
                  customFee: customFee,
                ),
              );
            } else {
              if (_selectedExisting == null) return;
              Navigator.pop(
                context,
                _EnrollFormResult.existing(_selectedExisting, customFee: customFee),
              );
            }
          },
          child: const Text('Enroll'),
        ),
      ],
    );
  }
}
