// Payment reminders — v1 scope.
//
// This is a desktop app with no SMS/WhatsApp Business API budget, so the
// practical version is: build a pre-filled WhatsApp message and hand off
// to WhatsApp Desktop (or WhatsApp Web) via a wa.me deep link, rather than
// sending anything ourselves. Staff still hits "send", they just don't
// have to type the message. Every send is logged to ReminderLog so a
// second staff member sees "reminded 2 days ago" instead of re-sending.
//
// TODO(claude-code): wire this into a "Due & overdue" dashboard screen
// that lists PaymentDao.dueOrOverdue() and puts a "Remind" button next to
// each row.

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';

const _uuid = Uuid();
final _currency = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
final _dateFmt = DateFormat('d MMM yyyy');

class ReminderService {
  final AppDatabase db;
  ReminderService(this.db);

  String buildMessage({
    required Student student,
    required Batch batch,
    required Payment payment,
  }) {
    final amount = _currency.format(payment.expectedAmount - payment.paidAmount);
    final due = _dateFmt.format(payment.dueDate);
    final isOverdue = payment.dueDate.isBefore(DateTime.now());

    return isOverdue
        ? 'Hi ${student.firstName}, this is a reminder from Temidove Smart '
            'Solutions that your $amount payment for ${batch.level ?? "your course"} '
            'was due on $due. Kindly clear this at your earliest convenience. Thank you.'
        : 'Hi ${student.firstName}, a friendly reminder from Temidove Smart '
            'Solutions — your next payment of $amount for '
            '${batch.level ?? "your course"} is due on $due. Thank you.';
  }

  /// Opens WhatsApp with the message pre-filled and logs the send. Returns
  /// false without logging if the link couldn't be opened (e.g. WhatsApp
  /// isn't installed), so the UI can show an error instead of a false
  /// "reminded" state.
  Future<bool> sendReminder({
    required Student student,
    required Batch batch,
    required Payment payment,
    required String message,
    String? sentByStaffId,
  }) async {
    final phone = _normalizePhone(student.phone);
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) return false;

    await db.reminderDao.log(ReminderLogCompanion.insert(
      id: _uuid.v4(),
      paymentId: payment.id,
      channel: const Value('whatsapp'),
      sentByStaffId: Value(sentByStaffId),
    ));
    return true;
  }

  /// wa.me needs digits only, with country code, no leading zero/plus.
  /// Uganda numbers in the old system were stored as local (07...), so
  /// this assumes +256 when the number starts with 0. Adjust if the real
  /// data has other formats mixed in — worth checking against actual
  /// student records during import.
  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) return '256${digits.substring(1)}';
    if (digits.startsWith('256')) return digits;
    return digits;
  }
}
