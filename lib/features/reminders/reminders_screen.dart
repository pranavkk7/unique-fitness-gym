import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/member_profile_screen.dart';
import '../more/templates_screen.dart';
import '../shell/shell_controller.dart';
import 'reminder_runner.dart';

/// Everyone who needs a WhatsApp message today, grouped by reason, with one button to work
/// through a whole list.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderKind _kind = ReminderKind.expiring;
  bool _showSent = false;
  int _seenRequest = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = context.read<ShellController>();
    if (shell.requestVersion != _seenRequest) {
      _seenRequest = shell.requestVersion;
      final gym = context.read<GymProvider>();
      // Open on the requested list, or on the first list with someone in it.
      _kind = shell.reminderKind ?? GymMessages.queueKinds.firstWhere((k) => gym.reminderQueue(k).isNotEmpty, orElse: () => ReminderKind.expiring);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final pending = gym.reminderQueue(_kind);
    final all = gym.reminderQueue(_kind, includeSent: true);
    final shown = _showSent ? all : pending;
    final sentCount = all.length - pending.length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RevealText('REMINDERS', style: AppText.display),
                    Text('${gym.pendingReminderCount} ready to send today', style: AppText.small.copyWith(color: AppColors.muted)),
                  ]),
                ),
                IconButton(tooltip: 'Message templates', icon: const Icon(Icons.edit_note_rounded), onPressed: () => openPage(context, const TemplatesScreen())),
              ],
            ).entrance(context),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              children: [
                for (var i = 0; i < GymMessages.queueKinds.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _KindCard(
                      kind: GymMessages.queueKinds[i],
                      count: gym.reminderQueue(GymMessages.queueKinds[i]).length,
                      selected: _kind == GymMessages.queueKinds[i],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _kind = GymMessages.queueKinds[i]);
                      },
                    ).entrance(context, index: i),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          sliver: SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: pending.isEmpty
                  ? AppCard(
                      key: ValueKey('done-${_kind.name}'),
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        const Icon(Icons.task_alt_rounded, color: AppColors.success, size: 30),
                        const SizedBox(width: 14),
                        Expanded(child: Text(all.isEmpty ? 'Nobody on this list today.' : 'All ${all.length} sent. Nice work!', style: AppText.title)),
                      ]),
                    )
                  : _SendAllButton(
                      key: ValueKey('send-${_kind.name}'),
                      kind: _kind,
                      count: pending.length,
                      onTap: () => runReminderQueue(context, _kind),
                    ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 18, 8, 4),
          sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: Text(_kind.label.toUpperCase(), style: AppText.label.copyWith(color: AppColors.text))),
              if (sentCount > 0)
                TextButton.icon(
                  onPressed: () => setState(() => _showSent = !_showSent),
                  icon: Icon(_showSent ? Icons.visibility_off_rounded : Icons.history_rounded, size: 18),
                  label: Text(_showSent ? 'Hide sent' : 'Show $sentCount sent'),
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 140),
          sliver: SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) => _TargetRow(target: shown[i]).entrance(context, index: i),
          ),
        ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  final ReminderKind kind;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _KindCard({required this.kind, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${kind.label}, $count',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.settle,
          width: 118,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? kind.color.withValues(alpha: 0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kind.color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(kind.icon, color: kind.color, size: 20),
                const Spacer(),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text('$count', key: ValueKey(count), style: AppText.headline.copyWith(fontSize: 22, color: count == 0 ? AppColors.muted : AppColors.text)),
                ),
              ]),
              const Spacer(),
              Text(kind.label, style: AppText.small.copyWith(color: selected ? AppColors.text : AppColors.textSecondary, fontWeight: FontWeight.w700), maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendAllButton extends StatelessWidget {
  final ReminderKind kind;
  final int count;
  final VoidCallback onTap;

  const _SendAllButton({super.key, required this.kind, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1FBF5B), Color(0xFF0E7A3A)]),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.send_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SEND ALL $count', style: AppText.headline.copyWith(fontSize: 24)),
            Text('One tap per person · WhatsApp opens ready to send', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white, fontWeight: FontWeight.w600).copyWith(color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.white),
      ]),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final ReminderTarget target;

  const _TargetRow({required this.target});

  @override
  Widget build(BuildContext context) {
    final gym = context.read<GymProvider>();
    final m = target.member;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: m == null ? null : () => openPage(context, MemberProfileScreen(memberId: m.id)),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m != null)
              MemberAvatar(member: m, size: 46)
            else
              CircleAvatar(radius: 23, backgroundColor: AppColors.surfaceHigher, child: Text(initials(target.name), style: AppText.title.copyWith(fontSize: 15))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.name, style: AppText.title.copyWith(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(target.kind.icon, size: 13, color: target.kind.color),
                    const SizedBox(width: 4),
                    Flexible(child: Text(target.detail, style: AppText.small.copyWith(color: target.kind.color, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 6),
                  Text(target.message, style: AppText.small.copyWith(color: AppColors.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 4),
            target.sentRecently
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Tooltip(
                      message: 'Sent ${relativeDay(gym.lastReminder(target.id, target.kind)!, gym.today).toLowerCase()}',
                      child: const StatusPill('Sent', color: AppColors.success, icon: Icons.done_all_rounded),
                    ),
                  )
                : IconButton.filled(
                    tooltip: 'Send on WhatsApp',
                    style: IconButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.black),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: () async {
                      final ok = await openWhatsApp(context, target.phone, target.message);
                      if (ok) await gym.logReminder(target.kind, target.id);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
