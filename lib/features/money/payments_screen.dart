import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import 'payment_sheet.dart';

/// Every receipt, newest first, grouped by day, with the month's total.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late DateTime _month = context.read<GymProvider>().thisMonth;

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final inMonth = gym.payments.where((p) => sameMonth(p.date, _month)).toList()..sort((a, b) => b.date.compareTo(a.date));
    // One row per receipt.
    final receipts = <String, List<Payment>>{};
    for (final p in inMonth) {
      receipts.putIfAbsent(p.receiptNo, () => []).add(p);
    }
    final byDay = <DateTime, List<List<Payment>>>{};
    for (final r in receipts.values) {
      byDay.putIfAbsent(dateOnly(r.first.date), () => []).add(r);
    }
    final total = inMonth.fold(0.0, (s, p) => s + p.amount);
    final isCurrent = sameMonth(_month, gym.today);

    return SubPage(
      title: 'Payments',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'payment-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showCollectPayment(context),
        icon: const Icon(AppIcons.rupee),
        label: const Text('Collect', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        children: [
          Row(children: [
            IconButton(tooltip: 'Previous month', icon: const Icon(AppIcons.chevronLeft), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
            Expanded(child: Text(formatMonthYear(_month), textAlign: TextAlign.center, style: AppText.headline.copyWith(fontSize: 20))),
            IconButton(tooltip: 'Next month', icon: const Icon(AppIcons.chevronRight), onPressed: isCurrent ? null : () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
          ]),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Collected', style: AppText.label),
                  CountUp(value: total, format: formatMoney, style: AppText.display.copyWith(fontSize: 36)),
                ]),
              ),
              Text('${receipts.length} receipts', style: AppText.small.copyWith(color: AppColors.muted)),
            ]),
          ).entrance(context),
          if (receipts.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: AppIcons.receipt, title: 'No payments', subtitle: 'Nothing was collected this month.')),
          for (final day in byDay.entries) ...[
            SectionHeader('${relativeDay(day.key, gym.today)} · ${formatMoney(day.value.expand((r) => r).fold(0.0, (s, p) => s + p.amount))}'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final r in day.value)
                  ListTile(
                    onTap: () => showReceiptActions(context, r.first.receiptNo),
                    leading: IconBadge(r.first.method.icon, color: AppColors.success, size: 38),
                    title: Text(gym.payerOf(r.first), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('${r.first.receiptNo} · ${formatTime(r.first.date)} · ${r.map((p) => p.kind.label).toSet().join(' + ')}', style: AppText.small.copyWith(color: AppColors.muted)),
                    trailing: Text(formatMoney(r.fold(0.0, (s, p) => s + p.amount)), style: AppText.number),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
