import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../payments/record_payment_dialog.dart';

const _statuses = ['waiting', 'started', 'completed', 'cancelled'];

/// Full student record: enrollments, payment history per enrollment,
/// notes, and staff-assignment editing — the equivalent of the old
/// dashboard.php edit/view modals, but as a real screen since there's
/// much more to show now (multiple enrollments, full payment history).
class StudentDetailScreen extends StatelessWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Student')),
      body: StreamBuilder<Student?>(
        stream: db.studentDao.watchById(studentId),
        builder: (context, studentSnapshot) {
          final student = studentSnapshot.data;
          if (student == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _StudentHeader(student: student, db: db),
              const SizedBox(height: 24),
              Text('Enrollments',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              StreamBuilder<List<EnrollmentWithBatch>>(
                stream: db.enrollmentDao.watchForStudent(studentId),
                builder: (context, snapshot) {
                  final enrollments = snapshot.data ?? [];
                  if (enrollments.isEmpty) {
                    return const Text('No enrollments yet.');
                  }
                  return Column(
                    children: enrollments
                        .map((e) => _EnrollmentCard(
                              enrollmentWithBatch: e,
                              db: db,
                              currency: currency,
                              dateFmt: dateFmt,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              _NotesEditor(student: student, db: db),
            ],
          );
        },
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  final Student student;
  final AppDatabase db;
  const _StudentHeader({required this.student, required this.db});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${student.firstName} ${student.lastName}',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(student.phone),
            if (student.email != null) Text(student.email!),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status: '),
                DropdownButton<String>(
                  value: student.status,
                  items: _statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) db.studentDao.updateStatus(student.id, v);
                  },
                ),
                const SizedBox(width: 24),
                const Text('Assigned staff: '),
                Expanded(
                  child: StreamBuilder<List<StaffData>>(
                    stream: db.staffDao.watchAll(),
                    builder: (context, snapshot) {
                      final staff = snapshot.data ?? [];
                      return DropdownButton<String?>(
                        isExpanded: true,
                        value: student.assignedStaffId,
                        hint: const Text('Unassigned'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Unassigned')),
                          ...staff.map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.fullName),
                              )),
                        ],
                        onChanged: (v) =>
                            db.studentDao.assignStaff(student.id, v),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  final EnrollmentWithBatch enrollmentWithBatch;
  final AppDatabase db;
  final NumberFormat currency;
  final DateFormat dateFmt;

  const _EnrollmentCard({
    required this.enrollmentWithBatch,
    required this.db,
    required this.currency,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final enrollment = enrollmentWithBatch.enrollment;
    final batch = enrollmentWithBatch.batch;
    final department = enrollmentWithBatch.department;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
            '${department.name} · ${batch.level ?? "—"} (${batch.instructorName ?? "no instructor"})'),
        subtitle: Text(
          'Enrolled ${dateFmt.format(enrollment.enrolledOn)}'
          '${enrollment.customFee != null ? " · custom fee ${currency.format(enrollment.customFee)}" : ""}',
        ),
        children: [
          StreamBuilder<List<Payment>>(
            stream: db.paymentDao.watchForEnrollment(enrollment.id),
            builder: (context, snapshot) {
              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No payment schedule generated.'),
                );
              }
              return Column(
                children: payments
                    .map((p) => _PaymentTile(
                          payment: p,
                          db: db,
                          currency: currency,
                          dateFmt: dateFmt,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Payment payment;
  final AppDatabase db;
  final NumberFormat currency;
  final DateFormat dateFmt;

  const _PaymentTile({
    required this.payment,
    required this.db,
    required this.currency,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final status = PaymentDao.effectiveStatus(payment);
    final balance = payment.expectedAmount - payment.paidAmount;
    final statusColor = switch (status) {
      'paid' => Colors.green,
      'overdue' => Colors.red,
      'partial' => Colors.amber,
      _ => Colors.grey,
    };

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: statusColor.shade100,
        child: Icon(Icons.circle, size: 10, color: statusColor.shade800),
      ),
      title: Text(
          'Due ${dateFmt.format(payment.dueDate)} · ${currency.format(payment.expectedAmount)}'),
      subtitle: Text(status == 'paid'
          ? 'Paid ${payment.datePaid != null ? dateFmt.format(payment.datePaid!) : ""}'
          : '$status · ${currency.format(balance)} outstanding'),
      trailing: status == 'paid'
          ? null
          : TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => RecordPaymentDialog(db: db, payment: payment),
              ),
              child: const Text('Record payment'),
            ),
    );
  }
}

class _NotesEditor extends StatefulWidget {
  final Student student;
  final AppDatabase db;
  const _NotesEditor({required this.student, required this.db});

  @override
  State<_NotesEditor> createState() => _NotesEditorState();
}

class _NotesEditorState extends State<_NotesEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.student.notes ?? '');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => widget.db.studentDao.updateNotes(
              widget.student.id,
              _controller.text.trim().isEmpty ? null : _controller.text.trim(),
            ),
            child: const Text('Save notes'),
          ),
        ),
      ],
    );
  }
}
