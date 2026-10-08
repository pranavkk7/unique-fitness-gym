import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../models/models.dart';
import '../../core/utils/contact.dart';
import '../../device/device_service.dart';
import '../../providers/gym_provider.dart';
import '../members/member_profile_screen.dart';
import 'checkin_flow.dart';

/// The front-desk check-in tab: scan a member card, or search and tap.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _search = TextEditingController();
  bool _showExpired = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final today = gym.checkInsToday;
    var list = gym.searchMembers(query: _search.text);
    if (!_showExpired) list = list.where(gym.isRunning).toList();
    // Not-yet-checked-in first, so the desk sees who is still to come.
    list.sort((a, b) => (gym.checkedInToday(a.id) ? 1 : 0).compareTo(gym.checkedInToday(b.id) ? 1 : 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 140),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RevealText('Check-in', style: AppText.display),
                Text('${today.length} in today · ${gym.recentlyIn()} in the last 90 min', style: AppText.small.copyWith(color: AppColors.muted)),
              ]),
            ),
          ],
        ).entrance(context),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBadge(AppIcons.faceId, color: AppColors.categorical[0], size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Face ID at the door', style: AppText.title.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    device.configured
                        ? '${syncAgo(gym.settings.lastDeviceSync, gym.now)}. Check someone in here when the device misses them.'
                        : 'Members walk in with Face ID. Check someone in here when the device misses them or for a trial visit.',
                    style: AppText.small.copyWith(color: AppColors.muted),
                  ),
                ]),
              ),
              if (device.configured)
                IconButton(
                  tooltip: 'Sync with the door',
                  onPressed: device.busy
                      ? null
                      : () async {
                          try {
                            final r = await device.sync();
                            if (context.mounted) showMessage(context, r.imported == 0 ? 'Up to date.' : '${r.imported} new entries from the door.');
                          } catch (_) {
                            if (context.mounted) showMessage(context, device.error ?? 'Could not reach the device.');
                          }
                        },
                  icon: device.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)) : const Icon(AppIcons.sync),
                ),
            ],
          ),
        ).entrance(context, index: 1),
        if (today.isNotEmpty) ...[
          const SectionHeader('In today'),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: today.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final m = gym.memberById(today[i].memberId);
                if (m == null) return const SizedBox();
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => openPage(context, MemberProfileScreen(memberId: m.id)),
                  child: SizedBox(
                    width: 58,
                    child: Column(children: [
                      MemberAvatar(member: m, size: 50, heroTag: '-today'),
                      const SizedBox(height: 4),
                      Text(formatTime(today[i].time), style: AppText.small.copyWith(fontSize: 10.5, color: AppColors.muted), maxLines: 1),
                    ]),
                  ),
                ).entrance(context, index: i);
              },
            ),
          ),
        ],
        const SectionHeader('Find a member'),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Name, phone or UFG code',
            prefixIcon: const Icon(AppIcons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(AppIcons.close), onPressed: () => setState(_search.clear)),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _showExpired,
          onChanged: (v) => setState(() => _showExpired = v),
          title: Text('Show expired members', style: AppText.body.copyWith(color: AppColors.textSecondary)),
        ),
        if (list.isEmpty)
          EmptyState(icon: AppIcons.personSearch, title: gym.hasMembers ? 'Nobody found' : 'No members yet', subtitle: gym.hasMembers ? 'Try another name or number.' : 'Add a member first.')
        else
          for (var i = 0; i < list.length && i < 60; i++) _Row(member: list[i]).entrance(context, index: i),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final Member member;

  const _Row({required this.member});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final done = gym.checkInsToday.where((c) => c.memberId == member.id).firstOrNull;
    return MemberTile(
      member: member,
      onTap: () => openPage(context, MemberProfileScreen(memberId: member.id)),
      trailing: AnimatedSwitcher(
        duration: Motion.medium,
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done != null
            ? Column(
                key: const ValueKey('done'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const StatusPill('In', color: AppColors.success, icon: AppIcons.check),
                  const SizedBox(height: 4),
                  Text(formatTime(done.time), style: AppText.small.copyWith(color: AppColors.muted, fontSize: 11)),
                ],
              )
            : FilledButton(
                key: const ValueKey('go'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => runCheckIn(context, member),
                child: const Text('Check in'),
              ),
      ),
    );
  }
}
