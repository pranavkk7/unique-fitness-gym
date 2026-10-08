import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../money/offers_screen.dart';
import '../money/payment_sheet.dart';
import 'plan_picker.dart';

/// Renews a membership: pick a plan, apply a discount, take the payment, and see the new dates
/// before confirming.
Future<void> showRenewSheet(BuildContext context, Member member) async {
  final receipt = await showAppSheet<String?>(context, builder: (_) => _RenewSheet(member: member));
  if (receipt != null && receipt.isNotEmpty && context.mounted) await showReceiptActions(context, receipt, justPaid: true);
}

class _RenewSheet extends StatefulWidget {
  final Member member;

  const _RenewSheet({required this.member});

  @override
  State<_RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<_RenewSheet> {
  late String _planId;
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  late PayMethod _method = context.read<GymProvider>().lastPayMethod;
  bool _saving = false;
  bool _paidEdited = false;
  Offer? _offer;
  double _offerDiscount = 0;

  @override
  void initState() {
    super.initState();
    final gym = context.read<GymProvider>();
    final current = gym.planById(widget.member.planId);
    _planId = (current != null && current.active ? current : gym.activePlans.first).id;
    _syncPaid();
  }

  @override
  void dispose() {
    _discount.dispose();
    _paid.dispose();
    super.dispose();
  }

  double get _price => context.read<GymProvider>().planById(_planId)!.price;
  double get _manualDiscount => (parseAmount(_discount.text) ?? 0).clamp(0, _price).toDouble();
  double get _discountValue => (_manualDiscount + _offerDiscount).clamp(0, _price).toDouble();
  double get _bill => _price - _discountValue;

  /// Until the amount is typed by hand, it follows the bill.
  void _syncPaid() {
    if (!_paidEdited) _paid.text = _bill.toStringAsFixed(0);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final gym = context.read<GymProvider>();
    final (renewed, payment) = await gym.renew(widget.member.id, planId: _planId, discount: _discountValue, amountPaid: parseAmount(_paid.text) ?? 0, method: _method, offerId: _offer?.id);
    if (!mounted) return;
    showMessage(context, '${renewed.firstName} renewed till ${formatDate(renewed.endDate)}.');
    Navigator.pop(context, payment?.receiptNo ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final m = widget.member;
    final plan = gym.planById(_planId)!;
    final running = gym.daysLeft(m) >= 0;
    final start = running ? dateOnly(m.endDate) : gym.today;
    final end = addMonths(start, plan.months);
    final paid = parseAmount(_paid.text) ?? 0;
    final newDue = (m.balanceDue + _bill - paid).clamp(0, double.infinity).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Renew ${m.firstName}', subtitle: running ? 'Continues from ${formatDate(m.endDate)}, so no days are lost.' : 'Expired on ${formatDate(m.endDate)}. The new plan starts today.'),
          PlanPicker(
            plans: gym.activePlans,
            selectedId: _planId,
            onSelected: (p) => setState(() {
              _planId = p.id;
              _syncPaid();
            }),
          ),
          const SizedBox(height: 14),
          AppCard(
            color: AppColors.surfaceHigh,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(AppIcons.eventAvailable, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(child: Text('New period ${formatDate(start)} – ${formatDate(end)}', style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount', prefixText: '₹ ', prefixIcon: Icon(AppIcons.tag)),
                  onChanged: (_) => setState(_syncPaid),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _paid,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Paid now', prefixText: '₹ ', prefixIcon: Icon(AppIcons.cash)),
                  onChanged: (_) => setState(() => _paidEdited = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OfferCodeField(
            price: plan.price - _manualDiscount,
            onChanged: (offer, discount) => setState(() {
              _offer = offer;
              _offerDiscount = discount;
              _syncPaid();
            }),
          ),
          const FieldLabel('Paid by'),
          PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
          UpiQrPanel(show: _method == PayMethod.upi, amount: paid, note: '${memberCode(m.number)} renewal'),
          CashChange(show: _method == PayMethod.cash, amount: paid),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                BillRow(plan.name, plan.price),
                if (_manualDiscount > 0) BillRow('Discount', _manualDiscount, negative: true, color: AppColors.success),
                if (_offer != null && _offerDiscount > 0) BillRow('Offer ${_offer!.code}', _offerDiscount, negative: true, color: AppColors.success),
                if (m.balanceDue > 0) BillRow('Earlier balance', m.balanceDue),
                const Divider(height: 18),
                BillRow('Total', _bill + m.balanceDue, bold: true),
                BillRow('Paid now', paid),
                if (newDue > 0) BillRow('Balance after this', newDue, color: AppColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(AppIcons.renew), label: Text('Renew till ${formatDayMonth(end)}')),
        ],
      ),
    );
  }
}
