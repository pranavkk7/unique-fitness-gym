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
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import '../members/member_profile_screen.dart';
import '../money/payment_sheet.dart';

/// The members in one class batch: add or remove people up to the capacity, see who came in
/// today, and share a message with the batch.
class ClassRosterScreen extends StatelessWidget {
  final String classId;
  final VoidCallback? onEdit;

  const ClassRosterScreen({super.key, required this.classId, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final c = gym.classes.where((x) => x.id == classId).firstOrNull;
    if (c == null) return const SubPage(title: 'Class', child: SizedBox.shrink());
    final roster = [for (final id in c.memberIds) ?gym.memberById(id)]..sort((a, b) => a.name.compareTo(b.name));
    final inToday = gym.checkIns.where((x) => sameDay(x.time, gym.today)).map((x) => x.memberId).toSet();
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final full = c.spotsLeft == 0;

    return SubPage(
      title: c.title,
      subtitle: '${c.weekdays.map((d) => days[d - 1]).join(', ')} · ${minutesLabel(c.startMinutes)} · ${gym.trainerById(c.trainerId)?.name ?? 'No trainer'}',
      actions: [if (onEdit != null) IconButton(tooltip: 'Edit class', icon: const Icon(AppIcons.edit), onPressed: onEdit)],
      floatingAction: FloatingActionButton.extended(
        heroTag: 'roster-fab',
        backgroundColor: full ? AppColors.surfaceHigher : AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: full
            ? () => showMessage(context, 'The batch is full. Raise the capacity to add more.')
            : () async {
                final m = await pickMember(context, title: 'Add to ${c.title}', runningOnly: true);
                if (m == null || !context.mounted) return;
                final ok = await gym.enrollInClass(c.id, m.id);
                if (context.mounted) showMessage(context, ok ? '${m.firstName} added to the batch.' : 'The batch is full.');
              },
        icon: const Icon(AppIcons.personAdd),
        label: Text(full ? 'Batch full' : 'Add member', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
        children: [
          AppCard(
            child: Row(children: [
              ProgressRing(
                value: c.capacity == 0 ? 0 : roster.length / c.capacity,
                size: 86,
                stroke: 9,
                color: full ? AppColors.warning : c.type.color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${roster.length}', style: AppText.headline.copyWith(fontSize: 26)),
                  Text('of ${c.capacity}', style: AppText.small.copyWith(color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(full ? 'Batch is full' : '${c.spotsLeft} spots left', style: AppText.title),
                  const SizedBox(height: 4),
                  Text('${roster.where((m) => inToday.contains(m.id)).length} of the batch checked in today', style: AppText.small.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: roster.isEmpty ? null : () => _message(context, c, roster),
                    icon: const Icon(AppIcons.campaign, size: 18),
                    label: const Text('Message batch'),
                  ),
                ]),
              ),
            ]),
          ).entrance(context),
          const SectionHeader('Members'),
          if (roster.isEmpty) const EmptyState(icon: AppIcons.groups, title: 'No one in this batch', subtitle: 'Add members who have joined this class.'),
          for (var i = 0; i < roster.length; i++)
            Dismissible(
              key: ValueKey(roster[i].id),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(AppIcons.personRemove, color: AppColors.danger)),
              onDismissed: (_) => gym.removeFromClass(c.id, roster[i].id),
              child: MemberTile(
                member: roster[i],
                subtitle: inToday.contains(roster[i].id) ? 'In today' : null,
                trailing: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: inToday.contains(roster[i].id) ? const Icon(AppIcons.checkCircle, color: AppColors.success) : const Icon(AppIcons.chevronRight, color: AppColors.muted),
                ),
                onTap: () => openPage(context, MemberProfileScreen(memberId: roster[i].id)),
              ),
            ).entrance(context, index: i < 12 ? i + 1 : 12),
          if (roster.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Swipe left to remove someone from the batch.', style: AppText.small.copyWith(color: AppColors.muted), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  /// Most batches have a WhatsApp group, so the message is shared once through the share sheet.
  Future<void> _message(BuildContext context, GymClass c, List<Member> roster) async {
    final ctrl = TextEditingController(text: '${c.title} update: ');
    final send = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Message ${roster.length} members'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, maxLines: 4),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in ['Class cancelled today', 'Starting 15 minutes late', 'New batch timing from Monday'])
              ActionChip(label: Text(t), onPressed: () => ctrl.text = '${c.title}: $t.'),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(d, true), child: const Text('Share')),
        ],
      ),
    );
    if (send == true && context.mounted) await shareText(context, ctrl.text, subject: c.title);
    ctrl.dispose();
  }
}
