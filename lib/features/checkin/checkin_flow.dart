import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/member_widgets.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/renew_sheet.dart';

/// Checks a member in from the desk or a QR scan and shows the result card. Expired and frozen
/// memberships stop and ask what to do, so staff never let someone in by accident.
Future<void> runCheckIn(BuildContext context, Member member, {CheckInSource source = CheckInSource.desk}) async {
  final gym = context.read<GymProvider>();
  var outcome = await gym.checkIn(member.id, source: source);
  if (!context.mounted) return;

  if (outcome == CheckInOutcome.blockedExpired || outcome == CheckInOutcome.blockedFrozen) {
    HapticFeedback.heavyImpact();
    final frozen = outcome == CheckInOutcome.blockedFrozen;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const SuccessBurst(kind: BurstKind.warning, size: 96),
        title: Text(frozen ? 'MEMBERSHIP FROZEN' : 'MEMBERSHIP EXPIRED', textAlign: TextAlign.center),
        content: Text(
          frozen
              ? '${member.firstName}\'s membership is paused till ${formatDate(member.freezeOn(gym.today)!.end)}.'
              : '${member.firstName}\'s ${gym.planById(member.planId)?.name ?? ''} plan ended on ${formatDate(member.endDate)}.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, 'once'), child: Text(frozen ? 'End freeze & check in' : 'Allow once')),
          if (!frozen) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(dialogContext, 'renew'), child: const Text('RENEW NOW')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'renew') {
      await showRenewSheet(context, member);
      if (!context.mounted || gym.statusOf(gym.memberById(member.id)!) == MemberStatus.expired) return;
      outcome = await gym.checkIn(member.id, source: source);
    } else if (choice == 'once') {
      if (frozen) await gym.unfreeze(member.id);
      outcome = await gym.checkIn(member.id, source: source, allowExpired: true);
    } else {
      return;
    }
    if (!context.mounted) return;
  }

  final fresh = gym.memberById(member.id) ?? member;
  final checkInId = gym.checkInsToday.where((c) => c.memberId == member.id).firstOrNull?.id;
  HapticFeedback.mediumImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: Motion.medium,
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.pop)), child: child),
    ),
    pageBuilder: (dialogContext, _, _) => CheckInResultCard(
      member: fresh,
      duplicate: outcome == CheckInOutcome.duplicateToday,
      onUndo: checkInId == null || outcome == CheckInOutcome.duplicateToday
          ? null
          : () {
              gym.undoCheckIn(checkInId);
              Navigator.pop(dialogContext);
            },
    ),
  );
}

/// The result card: big tick, the member's face, days left and any dues. Closes itself after a
/// few seconds so the desk is ready for the next person.
class CheckInResultCard extends StatefulWidget {
  final Member member;
  final bool duplicate;
  final VoidCallback? onUndo;

  const CheckInResultCard({super.key, required this.member, this.duplicate = false, this.onUndo});

  @override
  State<CheckInResultCard> createState() => _CheckInResultCardState();
}

class _CheckInResultCardState extends State<CheckInResultCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.maybePop(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final m = widget.member;
    final left = gym.daysLeft(m);
    final style = StatusStyle.of(gym, m);
    final visits = gym.visitsInLast(m.id, 30);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: (widget.duplicate ? AppColors.warning : AppColors.success).withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: (widget.duplicate ? AppColors.warning : AppColors.success).withValues(alpha: 0.25), blurRadius: 50, spreadRadius: -10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The member's face, with the animated tick as a badge on its corner.
              SizedBox(
                width: 150,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MemberAvatar(member: m, size: 104, hero: false, ringColor: widget.duplicate ? AppColors.warning : AppColors.success),
                    Align(alignment: const Alignment(1.05, 0.95), child: SuccessBurst(kind: widget.duplicate ? BurstKind.warning : BurstKind.success, size: 78, backing: AppColors.surface)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.duplicate ? 'ALREADY IN TODAY' : 'CHECKED IN', style: AppText.label.copyWith(color: widget.duplicate ? AppColors.warning : AppColors.success, letterSpacing: 2.4)),
              const SizedBox(height: 4),
              Text(m.name.toUpperCase(), style: AppText.display.copyWith(fontSize: 28), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('${memberCode(m.number)} · ${formatTime(gym.now)} · $visits visits this month', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  StatusPill(left >= 0 ? '$left days left' : 'Expired', color: style.color, icon: style.icon),
                  if (m.balanceDue > 0) StatusPill('${formatMoney(m.balanceDue)} due', color: AppColors.danger, icon: Icons.account_balance_wallet_rounded),
                  if (gym.birthdaysToday.any((b) => b.id == m.id)) StatusPill('Birthday today', color: AppColors.categorical[1], icon: Icons.cake_rounded),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (widget.onUndo != null) TextButton(onPressed: widget.onUndo, child: const Text('Undo')),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
