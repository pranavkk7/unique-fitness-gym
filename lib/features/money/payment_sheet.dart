import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/plan_picker.dart';
import 'receipt_pdf.dart';

/// Takes a payment from a member. With no [member], asks who is paying first.
Future<void> showCollectPayment(BuildContext context, {Member? member, double? amount}) async {
  final who = member ?? await pickMember(context, title: 'Who is paying?');
  if (who == null || !context.mounted) return;
  final receipt = await showAppSheet<String>(context, builder: (_) => _PaymentSheet(member: who, initialAmount: amount ?? (who.balanceDue > 0 ? who.balanceDue : null)));
  if (receipt != null && context.mounted) await showReceiptActions(context, receipt, justPaid: true);
}

/// A searchable list of members in a sheet. Returns the chosen member.
Future<Member?> pickMember(BuildContext context, {required String title, bool runningOnly = false}) {
  return showAppSheet<Member>(context, builder: (_) => _MemberPicker(title: title, runningOnly: runningOnly));
}

class _MemberPicker extends StatefulWidget {
  final String title;
  final bool runningOnly;

  const _MemberPicker({required this.title, required this.runningOnly});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    var list = gym.searchMembers(query: _query);
    if (widget.runningOnly) list = list.where(gym.isRunning).toList();
    // People with dues first: they are the most likely to be paying.
    list.sort((a, b) => (b.balanceDue > 0 ? 1 : 0).compareTo(a.balanceDue > 0 ? 1 : 0));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        child: Column(
          children: [
            SheetHeader(widget.title),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(hintText: 'Name, phone or UFG code', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => MemberTile(member: list[i], onTap: () => Navigator.pop(context, list[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  final Member member;
  final double? initialAmount;

  const _PaymentSheet({required this.member, this.initialAmount});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.initialAmount == null ? '' : widget.initialAmount!.toStringAsFixed(0));
  final _note = TextEditingController();
  late PayMethod _method = context.read<GymProvider>().lastPayMethod;
  PaymentKind _kind = PaymentKind.membership;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final gym = context.read<GymProvider>();
    final p = await gym.recordPayment(widget.member.id, amount: parseAmount(_amount.text)!, method: _method, kind: _kind, note: _note.text.trim());
    if (mounted) Navigator.pop(context, p.receiptNo);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final amount = parseAmount(_amount.text) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MemberAvatar(member: m, size: 46, hero: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COLLECT PAYMENT', style: AppText.headline.copyWith(fontSize: 20)),
                      Text('${m.name} · ${m.balanceDue > 0 ? '${formatMoney(m.balanceDue)} due' : 'No balance due'}', style: AppText.small.copyWith(color: m.balanceDue > 0 ? AppColors.danger : AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AmountField(
              controller: _amount,
              label: 'Amount received',
              autofocus: widget.initialAmount == null,
              onChanged: (_) => setState(() {}),
              validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter the amount received' : null,
            ),
            const FieldLabel('For'),
            ChoiceChips<PaymentKind>(
              options: const [PaymentKind.membership, PaymentKind.personalTraining, PaymentKind.other],
              selected: _kind,
              labelOf: (k) => k == PaymentKind.membership ? 'Membership / dues' : k.label,
              onSelected: (k) => setState(() => _kind = k),
            ),
            const FieldLabel('Paid by'),
            PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
            UpiQrPanel(show: _method == PayMethod.upi, amount: amount, note: '${memberCode(m.number)} ${m.firstName}'),
            CashChange(show: _method == PayMethod.cash, amount: amount),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes_rounded))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(amount > 0 ? 'RECORD ${formatMoney(amount)}' : 'RECORD PAYMENT'),
            ),
            if (_kind != PaymentKind.membership && m.balanceDue > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${_kind.label} is extra income and does not reduce the membership balance.', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}

/// A scan-to-pay UPI QR for the exact amount, so the member pays with GPay or PhonePe at the desk.
/// Tap it to show it full screen and turn the phone or tablet towards the member. With demo data
/// loaded it wears a DEMO band and points at a payee no UPI app accepts.
class UpiQrPanel extends StatelessWidget {
  final bool show;
  final double amount;
  final String note;

  const UpiQrPanel({super.key, required this.show, required this.amount, this.note = ''});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final link = amount > 0 ? gym.upiLink(amount, note: note) : null;
    final demo = gym.upiIsDemo;
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.settle,
      child: !show || link == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Material(
                color: AppColors.surfaceHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showLarge(context, link, demo),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _UpiQr(link: link, demo: demo, size: 116),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SCAN TO PAY', style: AppText.label.copyWith(color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text(formatMoney(amount), style: AppText.headline.copyWith(fontSize: 24)),
                              Text(demo ? 'Sample QR for the demo' : gym.settings.gymName, style: AppText.small.copyWith(color: demo ? AppColors.warning : AppColors.muted)),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.open_in_full_rounded, size: 13, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Flexible(child: Text('Tap to show it big', style: AppText.small.copyWith(color: AppColors.muted, fontSize: 11.5))),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _showLarge(BuildContext context, String link, bool demo) {
    final gym = context.read<GymProvider>();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => GestureDetector(
        onTap: () => Navigator.pop(dialogContext),
        child: Center(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gym.settings.gymName.toUpperCase(), style: AppText.headline.copyWith(color: const Color(0xFF111114), fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(formatMoney(amount), style: AppText.display.copyWith(color: AppColors.primary, fontSize: 44)),
                  const SizedBox(height: 14),
                  _UpiQr(link: link, demo: demo, size: 260),
                  const SizedBox(height: 14),
                  Text(demo ? 'Demo QR: payments will not go through' : 'Scan with GPay, PhonePe, Paytm or any UPI app',
                      style: AppText.small.copyWith(color: demo ? AppColors.primary : const Color(0xFF55555E))),
                  const SizedBox(height: 4),
                  Text('Tap anywhere to close', style: AppText.small.copyWith(color: const Color(0xFF8A8A94), fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The QR itself, with a diagonal DEMO band when it is the sample.
class _UpiQr extends StatelessWidget {
  final String link;
  final bool demo;
  final double size;

  const _UpiQr({required this.link, required this.demo, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(size * 0.07),
            color: Colors.white,
            child: QrImageView(data: link, size: size, padding: EdgeInsets.zero, semanticsLabel: demo ? 'Sample UPI QR code' : 'UPI payment QR code'),
          ),
          if (demo)
            Transform.rotate(
              angle: -0.6,
              child: Container(
                width: size * 1.6,
                padding: EdgeInsets.symmetric(vertical: size * 0.025),
                color: AppColors.primary.withValues(alpha: 0.92),
                child: Text('DEMO', textAlign: TextAlign.center, style: AppText.label.copyWith(color: Colors.white, letterSpacing: 4, fontSize: size * 0.1)),
              ),
            ),
        ],
      ),
    );
  }
}

/// For cash: tap the note the member hands over (or type it) and see the change to give back.
class CashChange extends StatefulWidget {
  final bool show;
  final double amount;

  const CashChange({super.key, required this.show, required this.amount});

  @override
  State<CashChange> createState() => _CashChangeState();
}

class _CashChangeState extends State<CashChange> {
  double? _given;

  /// The notes people usually hand over for this amount: the next round 500, 1000, 2000 or 5000.
  List<double> get _suggestions {
    final a = widget.amount;
    final options = <double>{};
    for (final step in [100.0, 500.0, 1000.0, 2000.0, 5000.0]) {
      final up = (a / step).ceil() * step;
      if (up > a) options.add(up);
    }
    return (options.toList()..sort()).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final change = _given == null ? null : _given! - widget.amount;
    return AnimatedSize(
      duration: Motion.medium,
      curve: Motion.settle,
      child: !widget.show || widget.amount <= 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.payments_rounded, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text('CASH GIVEN', style: AppText.label.copyWith(color: AppColors.text)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(label: const Text('Exact'), selected: _given == widget.amount, onSelected: (_) => setState(() => _given = widget.amount)),
                      for (final note in _suggestions)
                        ChoiceChip(label: Text(formatMoney(note)), selected: _given == note, onSelected: (_) => setState(() => _given = note)),
                    ]),
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      child: change == null
                          ? const SizedBox(key: ValueKey('none'), height: 0)
                          : Padding(
                              key: ValueKey(change),
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                change >= 0 ? (change == 0 ? 'No change to give' : 'Give back ${formatMoney(change)}') : '${formatMoney(-change)} short',
                                style: AppText.headline.copyWith(fontSize: 22, color: change >= 0 ? AppColors.success : AppColors.danger),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
/// After a payment: send the receipt on WhatsApp or share it as a PDF.
Future<void> showReceiptActions(BuildContext context, String receiptNo, {bool justPaid = false}) async {
  final gym = context.read<GymProvider>();
  final lines = gym.paymentsOnReceipt(receiptNo);
  if (lines.isEmpty) return;
  final member = gym.memberById(lines.first.memberId);
  final total = lines.fold(0.0, (s, p) => s + p.amount);
  await showAppSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (justPaid) const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
            const SizedBox(height: 8),
            Text(justPaid ? '${formatMoney(total)} RECEIVED' : 'RECEIPT $receiptNo', style: AppText.headline, textAlign: TextAlign.center),
            Text('$receiptNo · ${gym.payerOf(lines.first)}', style: AppText.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.black),
              onPressed: member == null
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      openWhatsApp(context, member.phone, gym.receiptText(receiptNo));
                    },
              icon: const Icon(Icons.chat_rounded),
              label: const Text('SEND ON WHATSAPP'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: () {
                Navigator.pop(sheetContext);
                shareReceiptPdf(context, receiptNo);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('SHARE PDF RECEIPT'),
            ),
            TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Done')),
          ],
        ),
      ),
    ),
  );
}
