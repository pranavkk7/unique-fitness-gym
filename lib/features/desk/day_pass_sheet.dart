import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/plan_picker.dart';
import '../money/payment_sheet.dart';

/// A walk-in who is not a member: a paid day pass or a free trial. Both are saved as enquiries so
/// the desk follows up and can turn them into an admission later.
Future<void> showDayPassSheet(BuildContext context, {bool trial = false}) async {
  final receipt = await showAppSheet<String>(context, builder: (_) => _DayPassSheet(trial: trial));
  if (receipt != null && receipt.isNotEmpty && context.mounted) await showReceiptActions(context, receipt, justPaid: true);
}

class _DayPassSheet extends StatefulWidget {
  final bool trial;

  const _DayPassSheet({required this.trial});

  @override
  State<_DayPassSheet> createState() => _DayPassSheetState();
}

class _DayPassSheetState extends State<_DayPassSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late final _price = TextEditingController(text: _gym.settings.dayPassPrice > 0 ? _gym.settings.dayPassPrice.toStringAsFixed(0) : '');
  late bool _trial = widget.trial;
  late PayMethod _method = _gym.lastPayMethod;
  bool _saving = false;

  GymProvider get _gym => context.read<GymProvider>();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final gym = _gym;
    if (_trial) {
      final e = await gym.startTrial(name: _name.text, phone: _phone.text);
      if (!mounted) return;
      Navigator.pop(context, '');
      showMessage(context, '${e.name} is on a ${gym.settings.trialDays}-day trial. Follow-up on ${formatDayMonth(e.nextFollowUp!)}.');
      return;
    }
    final price = parseAmount(_price.text)!;
    // Remember the price so it is filled in next time.
    if (gym.settings.dayPassPrice != price) await gym.updateSettings(gym.settings.copyWith(dayPassPrice: price));
    final pay = await gym.sellDayPass(name: _name.text, phone: _phone.text, amount: price, method: _method);
    if (mounted) Navigator.pop(context, pay.receiptNo);
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final amount = parseAmount(_price.text) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(_trial ? 'Free trial' : 'Day pass', subtitle: _trial ? '${gym.settings.trialDays} days free. Saved as an enquiry with a follow-up when it ends.' : 'One paid visit. Saved as an enquiry so the desk can call tomorrow.'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(AppIcons.ticket), label: Text('Day pass')),
                ButtonSegment(value: true, icon: Icon(AppIcons.hourglassHigh), label: Text('Free trial')),
              ],
              selected: {_trial},
              onSelectionChanged: (v) => setState(() => _trial = v.first),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(AppIcons.person)), validator: (v) => requiredText(v, 'Enter a name')),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(AppIcons.phone)), validator: validatePhone),
            if (!_trial) ...[
              const SizedBox(height: 12),
              AmountField(controller: _price, label: 'Day pass price', onChanged: (_) => setState(() {}), validator: (v) => (parseAmount(v ?? '') ?? 0) <= 0 ? 'Enter the price' : null),
              const FieldLabel('Paid by'),
              PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
              UpiQrPanel(show: _method == PayMethod.upi && amount > 0, amount: amount, note: 'Day pass'),
              CashChange(show: _method == PayMethod.cash && amount > 0, amount: amount),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: Icon(_trial ? AppIcons.play : AppIcons.check),
              label: Text(_trial ? 'Start trial' : 'Take ${amount > 0 ? formatMoney(amount) : 'payment'}'),
            ),
            if (!_trial) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Day pass visitors enter through the desk, not the Face ID door.', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
