import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../reminders/reminder_service.dart';

/// The "due & overdue" view — direct replacement for the manual Excel
/// "Payment Reminder Dashboard" sheet, but computed live instead of
/// hand-updated.
class PaymentsDashboardScreen extends StatefulWidget {
  const PaymentsDashboardScreen({super.key});

  @override
  State<PaymentsDashboardScreen> createState() =>
      _PaymentsDashboardScreenState();
}

class _PaymentsDashboardScreenState extends State<PaymentsDashboardScreen> {
  late Future<List<PaymentWithContext>> _future;
  final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final db = context.read<AppDatabase>();
    _future = db.paymentDao.dueOrOverdue(withinDays: 7);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(title: const Text('Payments due & overdue')),
      body: FutureBuilder<List<PaymentWithContext>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Text('Nothing due in the next 7 days. All caught up.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _PaymentRow(
              paymentContext: rows[i],
              currency: _currency,
              dateFmt: _dateFmt,
              onRemind: () => _sendReminder(db, rows[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendReminder(AppDatabase db, PaymentWithContext ctx) async {
    final service = ReminderService(db);
    final message = service.buildMessage(
      student: ctx.student,
      batch: ctx.batch,
      payment: ctx.payment,
    );

    // TODO(claude-code): replace with a proper dialog that lets staff edit
    // the message before sending, and shows the "last reminded" timestamp
    // from ReminderDao.lastForPayment. This is the minimal version.
    final sent = await service.sendReminder(
      student: ctx.student,
      batch: ctx.batch,
      payment: ctx.payment,
      message: message,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent
            ? 'Reminder opened in WhatsApp for ${ctx.student.firstName}'
            : 'Could not open WhatsApp — check the number for '
                '${ctx.student.firstName} ${ctx.student.lastName}'),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentWithContext paymentContext;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final VoidCallback onRemind;

  const _PaymentRow({
    required this.paymentContext,
    required this.currency,
    required this.dateFmt,
    required this.onRemind,
  });

  @override
  Widget build(BuildContext context) {
    final payment = paymentContext.payment;
    final status = PaymentDao.effectiveStatus(payment);
    final isOverdue = status == 'overdue';
    final balance = payment.expectedAmount - payment.paidAmount;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOverdue
            ? Colors.red.shade100
            : Colors.amber.shade100,
        child: Icon(
          isOverdue ? Icons.warning_amber : Icons.schedule,
          color: isOverdue ? Colors.red.shade800 : Colors.amber.shade800,
        ),
      ),
      title: Text('${paymentContext.student.firstName} ${paymentContext.student.lastName}'),
      subtitle: Text(
        '${paymentContext.batch.level ?? "—"} · due ${dateFmt.format(payment.dueDate)} '
        '· ${currency.format(balance)} outstanding',
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: onRemind,
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('Remind'),
      ),
    );
  }
}
