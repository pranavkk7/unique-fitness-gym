import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/forms.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/plan_picker.dart';

/// End of the day at the desk: what came in by method, what the cash drawer should hold, the
/// counted cash, and a summary sent to the owner on WhatsApp.
class CloseDayScreen extends StatefulWidget {
  const CloseDayScreen({super.key});

  @override
  State<CloseDayScreen> createState() => _CloseDayScreenState();
}

class _CloseDayScreenState extends State<CloseDayScreen> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<GymProvider>().closeFor(context.read<GymProvider>().today);
    if (existing != null) {
      _counted.text = existing.counted.toStringAsFixed(0);
      _note.text = existing.note;
    }
  }

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  String _report(GymProvider gym, DayClose c) {
    final s = gym.daySummary();
    final diff = c.difference;
    return [
      '*${gym.settings.gymName} · ${gym.settings.branchName}*',
      'Day closed: ${formatDate(c.date)}, ${formatTime(c.closedAt)}',
      '',
      'Cash: ${formatMoney(c.cashIn)}',
      'UPI: ${formatMoney(c.upi)}',
      if (c.card > 0) 'Card: ${formatMoney(c.card)}',
      if (c.bank > 0) 'Bank: ${formatMoney(c.bank)}',
      '*Total collected: ${formatMoney(c.total)}*',
      '',
      'Cash spent: ${formatMoney(c.cashOut)}',
      'Drawer should have: ${formatMoney(c.expectedCash)}',
      'Counted: ${formatMoney(c.counted)}${diff.abs() < 1 ? ' ✅' : ' (${diff > 0 ? 'extra' : 'short'} ${formatMoney(diff.abs())})'}',
      '',
      '${s.admissions} admissions · ${s.renewals} renewals · ${s.checkIns} check-ins · ${s.receipts} receipts',
      if (c.note.isNotEmpty) 'Note: ${c.note}',
    ].join('\n');
  }

  Future<void> _close() async {
    final counted = parseAmount(_counted.text);
    if (counted == null) {
      showMessage(context, 'Count the cash in the drawer first.');
      return;
    }
    setState(() => _saving = true);
    final gym = context.read<GymProvider>();
    final close = await gym.closeDay(counted: counted, note: _note.text);
    if (!mounted) return;
    setState(() => _saving = false);
    final owner = gym.settings.ownerPhone.isNotEmpty ? gym.settings.ownerPhone : gym.settings.phone;
    if (owner.isEmpty) {
      showMessage(context, 'Day closed. Add the owner\'s phone in Settings to send the report.');
      return;
    }
    await openWhatsApp(context, owner, _report(gym, close));
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final s = gym.daySummary();
    final expected = s.cash - s.cashOut;
    final counted = parseAmount(_counted.text);
    final diff = counted == null ? null : counted - expected;
    final total = s.cash + s.upi + s.card + s.bank;
    final closed = gym.closeFor(gym.today);
    final history = gym.dayCloses.where((c) => !sameDay(c.date, gym.today)).toList()..sort((a, b) => b.date.compareTo(a.date));
    const colors = AppColors.payMethods;

    return SubPage(
      title: 'Close the day',
      subtitle: '${formatWeekday(gym.today)}, ${formatDate(gym.today)}${closed == null ? '' : ' · closed at ${formatTime(closed.closedAt)}'}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          AppCard(
            gradient: AppColors.redGradient,
            glow: true,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Collected today', style: AppText.label.copyWith(color: Colors.white70)),
              CountUp(value: total, format: formatMoney, style: AppText.stat.copyWith(color: Colors.white, fontSize: 44)),
              Text('${s.receipts} receipts · ${s.admissions} admissions · ${s.renewals} renewals · ${s.checkIns} check-ins', style: AppText.small.copyWith(color: Colors.white)),
            ]),
          ).entrance(context),
          const SizedBox(height: 14),
          AppCard(
            child: Column(children: [
              SplitBar(parts: [(s.cash, colors[0]), (s.upi, colors[1]), (s.card, colors[2]), (s.bank, colors[3])]),
              const SizedBox(height: 12),
              for (final (i, label, value) in [(0, 'Cash', s.cash), (1, 'UPI', s.upi), (2, 'Card', s.card), (3, 'Bank transfer', s.bank)])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label, style: AppText.body)),
                    Text(formatMoney(value), style: AppText.number),
                  ]),
                ),
            ]),
          ).entrance(context, index: 1),
          const SectionHeader('Cash drawer'),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BillRow('Cash received', s.cash),
              BillRow('Cash spent today', s.cashOut, negative: true),
              const Divider(height: 18),
              BillRow('Should be in the drawer', expected, bold: true),
              const SizedBox(height: 14),
              AmountField(controller: _counted, label: 'Cash counted', onChanged: (_) => setState(() {})),
              AnimatedSwitcher(
                duration: Motion.medium,
                child: diff == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(diff.abs() < 1 ? 'ok' : diff > 0 ? 'over' : 'short'),
                        padding: const EdgeInsets.only(top: 12),
                        child: StatusPill(
                          diff.abs() < 1 ? 'Drawer matches' : '${diff > 0 ? 'Extra' : 'Short by'} ${formatMoney(diff.abs())}',
                          color: diff.abs() < 1 ? AppColors.success : diff > 0 ? AppColors.warning : AppColors.danger,
                          icon: diff.abs() < 1 ? AppIcons.checkCircle : AppIcons.error,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Why is it short or extra?')),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.white),
            onPressed: _saving ? null : _close,
            icon: const Icon(AppIcons.closeDay),
            label: Text(closed == null ? 'Close day & send to owner' : 'Update & send again'),
          ),
          if (history.isNotEmpty) ...[
            const SectionHeader('Earlier days'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final c in history.take(14))
                  ListTile(
                    leading: IconBadge(c.difference.abs() < 1 ? AppIcons.check : AppIcons.priority, color: c.difference.abs() < 1 ? AppColors.success : AppColors.danger, size: 36),
                    title: Text('${formatWeekday(c.date)}, ${formatDayMonth(c.date)}'),
                    subtitle: Text(c.difference.abs() < 1 ? 'Drawer matched${c.note.isEmpty ? '' : ' · ${c.note}'}' : '${c.difference > 0 ? 'Extra' : 'Short'} ${formatMoney(c.difference.abs())}${c.note.isEmpty ? '' : ' · ${c.note}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(formatMoney(c.total), style: AppText.number),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
