import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';

/// Records a payment (full or partial) against one scheduled installment —
/// the UI entry point for PaymentDao.recordPayment, replacing the manual
/// PAID/PENDING cell edits from the old Excel tracker.
class RecordPaymentDialog extends StatefulWidget {
  final AppDatabase db;
  final Payment payment;
  const RecordPaymentDialog(
      {super.key, required this.db, required this.payment});

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  late final _amountController = TextEditingController(
    text: (widget.payment.expectedAmount - widget.payment.paidAmount)
        .toStringAsFixed(0),
  );
  final _agentNameController = TextEditingController();
  final _agentPhoneController = TextEditingController();
  DateTime _datePaid = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final balance = widget.payment.expectedAmount - widget.payment.paidAmount;

    return AlertDialog(
      title: const Text('Record payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding balance: ${currency.format(balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount paid (UGX)'),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            TextField(
              controller: _agentNameController,
              decoration:
                  const InputDecoration(labelText: 'Mobile money agent name'),
            ),
            TextField(
              controller: _agentPhoneController,
              decoration: const InputDecoration(labelText: 'Agent phone'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                    'Date paid: ${DateFormat('d MMM yyyy').format(_datePaid)}'),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _datePaid,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _datePaid = picked);
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final amount = double.tryParse(_amountController.text);
            if (amount == null || amount <= 0) return;
            await widget.db.paymentDao.recordPayment(
              paymentId: widget.payment.id,
              amountPaid: amount,
              datePaid: _datePaid,
              agentName: _agentNameController.text.trim().isEmpty
                  ? null
                  : _agentNameController.text.trim(),
              agentPhone: _agentPhoneController.text.trim().isEmpty
                  ? null
                  : _agentPhoneController.text.trim(),
            );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
