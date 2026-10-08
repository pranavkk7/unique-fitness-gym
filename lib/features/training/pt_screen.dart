import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
import '../members/member_profile_screen.dart';
import '../members/plan_picker.dart';
import '../money/payment_sheet.dart';

/// Personal training: running packages with one-tap session marking, and what each trainer has
/// earned this month from their commission.
class PtScreen extends StatelessWidget {
  const PtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final active = gym.ptPackages.where((p) => p.isActive(gym.today)).toList()..sort((a, b) => a.left.compareTo(b.left));
    final month = gym.thisMonth;
    final sessionsToday = gym.ptPackages.expand((p) => p.sessions).where((s) => sameDay(s, gym.today)).length;
    final soldThisMonth = gym.ptPackages.where((p) => sameMonth(p.soldAt, month)).fold(0.0, (s, p) => s + p.price);
    final earners = [
      for (final t in gym.trainers)
        if (gym.ptPackages.any((p) => p.trainerId == t.id)) (t, gym.trainerEarnings(t.id, month), gym.ptPackages.where((p) => p.trainerId == t.id).expand((p) => p.sessions).where((s) => sameMonth(s, month)).length),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    return SubPage(
      title: 'Personal training',
      subtitle: '${active.length} running packages · $sessionsToday sessions today',
      floatingAction: FloatingActionButton.extended(
        heroTag: 'pt-fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => showSellPtSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('SELL PACKAGE', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          Row(children: [
            Expanded(child: FigureCard('Running', '${active.length}', AppColors.categorical[0])),
            const SizedBox(width: 10),
            Expanded(child: FigureCard('Sold · ${formatShortMonth(month)}', formatMoneyCompact(soldThisMonth), AppColors.success)),
            const SizedBox(width: 10),
            Expanded(child: FigureCard('Today', '$sessionsToday', AppColors.primaryBright)),
          ]).entrance(context),
          if (earners.isNotEmpty) ...[
            const SectionHeader('Trainer earnings this month'),
            AppCard(
              child: Column(children: [
                for (final (t, earned, sessions) in earners)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: AppColors.surfaceHigher, child: Text(initials(t.name), style: AppText.small.copyWith(color: AppColors.text))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.name, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                          Text(t.commissionPct > 0 ? '$sessions sessions · ${t.commissionPct.round()}% commission' : '$sessions sessions · set a commission under Trainers', style: AppText.small.copyWith(color: AppColors.muted)),
                        ]),
                      ),
                      Text(formatMoney(earned), style: AppText.number.copyWith(color: AppColors.success)),
                    ]),
                  ),
              ]),
            ),
          ],
          const SectionHeader('Running packages'),
          if (active.isEmpty)
            const EmptyState(icon: Icons.sports_rounded, title: 'No PT packages', subtitle: 'Sell a package of sessions to a member and mark each session here.')
          else
            for (var i = 0; i < active.length; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: PtPackageCard(package: active[i], showMember: true)).entrance(context, index: i + 1),
        ],
      ),
    );
  }
}

/// A package with a ring of sessions used and a button to mark today's session.
class PtPackageCard extends StatelessWidget {
  final PtPackage package;
  final bool showMember;

  const PtPackageCard({super.key, required this.package, this.showMember = false});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final p = package;
    final member = gym.memberById(p.memberId);
    final trainer = gym.trainerById(p.trainerId);
    final doneToday = p.sessions.any((s) => sameDay(s, gym.today));
    final daysLeft = dateOnly(p.expiresAt).difference(gym.today).inDays;
    return AppCard(
      onTap: showMember && member != null ? () => openPage(context, MemberProfileScreen(memberId: member.id)) : null,
      child: Row(children: [
        ProgressRing(
          value: p.sessionsTotal == 0 ? 0 : p.used / p.sessionsTotal,
          size: 64,
          stroke: 7,
          color: p.left <= 2 ? AppColors.warning : AppColors.primary,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${p.left}', style: AppText.headline.copyWith(fontSize: 20)),
            Text('LEFT', style: AppText.label.copyWith(fontSize: 8)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(showMember ? member?.name ?? 'Former member' : '${p.sessionsTotal} sessions', style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
            Text('${p.used}/${p.sessionsTotal} done · ${trainer?.name ?? 'Trainer'}', style: AppText.small.copyWith(color: AppColors.muted)),
            Text(daysLeft < 0 ? 'Expired' : 'Valid till ${formatDayMonth(p.expiresAt)}${daysLeft <= 7 ? ' · $daysLeft days left' : ''}', style: AppText.small.copyWith(color: daysLeft <= 7 ? AppColors.warning : AppColors.muted)),
          ]),
        ),
        if (p.isActive(gym.today))
          doneToday
              ? TextButton(
                  onPressed: () async {
                    await gym.undoPtSession(p.id);
                    if (context.mounted) showMessage(context, 'Last session removed.');
                  },
                  child: const Text('UNDO'),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await gym.usePtSession(p.id);
                    if (context.mounted) showMessage(context, 'Session ${p.used + 1} of ${p.sessionsTotal} marked.');
                  },
                  label: const Text('SESSION'),
                ),
      ]),
    );
  }
}

/// Sells a package of PT sessions with a trainer.
Future<void> showSellPtSheet(BuildContext context, {Member? member}) async {
  final who = member ?? await pickMember(context, title: 'Personal training for', runningOnly: true);
  if (who == null || !context.mounted) return;
  final receipt = await showAppSheet<String>(context, builder: (_) => _SellPtSheet(member: who));
  if (receipt != null && receipt.isNotEmpty && context.mounted) await showReceiptActions(context, receipt, justPaid: true);
}

class _SellPtSheet extends StatefulWidget {
  final Member member;

  const _SellPtSheet({required this.member});

  @override
  State<_SellPtSheet> createState() => _SellPtSheetState();
}

class _SellPtSheetState extends State<_SellPtSheet> {
  static const _options = [8, 12, 24];
  int _sessions = 12;
  int _validDays = 60;
  late String? _trainerId = widget.member.trainerId ?? context.read<GymProvider>().trainers.firstOrNull?.id;
  final _price = TextEditingController();
  final _paid = TextEditingController();
  late PayMethod _method = context.read<GymProvider>().lastPayMethod;
  bool _paidEdited = false;
  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _paid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = parseAmount(_price.text);
    if (_trainerId == null || price == null || price <= 0) {
      showMessage(context, 'Pick a trainer and enter the package price.');
      return;
    }
    setState(() => _saving = true);
    final (_, pay) = await context.read<GymProvider>().sellPtPackage(widget.member.id, trainerId: _trainerId!, sessions: _sessions, price: price, validDays: _validDays, amountPaid: parseAmount(_paid.text) ?? 0, method: _method);
    if (mounted) Navigator.pop(context, pay?.receiptNo ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final price = parseAmount(_price.text) ?? 0;
    final paid = parseAmount(_paid.text) ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader('Personal training', subtitle: widget.member.name),
          if (gym.trainers.isEmpty)
            const Text('Add a trainer first under More > Trainers.', style: AppText.bodyMuted)
          else ...[
            const FieldLabel('Trainer'),
            ChoiceChips<String>(options: [for (final t in gym.trainers) t.id], selected: _trainerId, labelOf: (id) => gym.trainerById(id)!.name, onSelected: (v) => setState(() => _trainerId = v)),
          ],
          const FieldLabel('Sessions'),
          ChoiceChips<int>(options: _options, selected: _sessions, labelOf: (n) => '$n sessions', onSelected: (v) => setState(() => _sessions = v)),
          const FieldLabel('Use within'),
          ChoiceChips<int>(options: const [30, 60, 90], selected: _validDays, labelOf: (d) => '$d days', onSelected: (v) => setState(() => _validDays = v)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: AmountField(
                controller: _price,
                label: 'Package price',
                onChanged: (_) => setState(() {
                  if (!_paidEdited) _paid.text = _price.text;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: AmountField(controller: _paid, label: 'Paid now', onChanged: (_) => setState(() => _paidEdited = true))),
          ]),
          if (price > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${formatMoney(price / _sessions)} per session${price > paid ? ' · ${formatMoney(price - paid)} goes to balance due' : ''}', style: AppText.small.copyWith(color: AppColors.muted))),
          const FieldLabel('Paid by'),
          PayMethodPicker(selected: _method, onSelected: (v) => setState(() => _method = v)),
          UpiQrPanel(show: _method == PayMethod.upi && paid > 0, amount: paid, note: 'Personal training'),
          CashChange(show: _method == PayMethod.cash && paid > 0, amount: paid),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _saving || gym.trainers.isEmpty ? null : _save, icon: const Icon(Icons.check_rounded), label: Text('SELL $_sessions SESSIONS')),
        ],
      ),
    );
  }
}

/// Member profile section: the running package, or a button to sell one.
class PtProfileSection extends StatelessWidget {
  final Member member;

  const PtProfileSection({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final active = gym.activePtPackage(member.id);
    final past = gym.ptPackagesFor(member.id).where((p) => p.id != active?.id).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('Personal training', actionLabel: active == null ? null : 'SELL MORE', onAction: () => showSellPtSheet(context, member: member)),
      if (active != null)
        PtPackageCard(package: active)
      else
        AppCard(
          onTap: () => showSellPtSheet(context, member: member),
          child: Row(children: [
            IconBadge(Icons.sports_rounded, color: AppColors.categorical[0]),
            const SizedBox(width: 12),
            Expanded(child: Text(past > 0 ? 'No running package · $past finished' : 'No personal training yet. Sell a package.', style: AppText.bodyMuted)),
            const Icon(Icons.add_circle_rounded, color: AppColors.primaryBright),
          ]),
        ),
    ]);
  }
}

