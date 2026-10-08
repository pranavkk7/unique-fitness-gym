import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/member_widgets.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../device/device_service.dart';
import '../../device/zk_protocol.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import 'face_id_sheet.dart';
import 'setup_guide_screen.dart';

/// The gym's eSSL Face ID terminal: connection, sync, door rules, and who still needs a face.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final running = gym.members.where(gym.isRunning).toList();
    final notRegistered = running.where((m) => m.deviceUserId == null || !m.faceEnrolled).toList();
    final blocked = gym.members.where((m) => m.deviceUserId != null && !gym.doorAccessAllowed(m) && gym.daysLeft(m) > -60).toList();
    return SubPage(
      title: 'Face ID device',
      subtitle: device.configured ? device.label : 'eSSL / ZKTeco terminal',
      actions: [IconButton(tooltip: 'Setup guide', icon: const Icon(AppIcons.help), onPressed: () => _openGuide(context))],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (!device.configured) ...[
            _FirstTimeCard(onGuide: () => _openGuide(context)).entrance(context),
            const SectionHeader('Connection', padding: EdgeInsets.fromLTRB(2, 18, 2, 12)),
            const _ConnectionForm(),
            const SizedBox(height: 18),
          ],
          const _StatusHero().entrance(context),
          const SizedBox(height: 12),
          if (device.lastReport != null) _ReportCard(report: device.lastReport!).entrance(context, index: 1),
          if (kIsWeb && !device.isDemo)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderColor: AppColors.warning.withValues(alpha: 0.3),
                child: Text('The browser cannot reach the device. Use the Android or iPhone app on the gym Wi-Fi.', style: AppText.small.copyWith(color: AppColors.warning)),
              ),
            ),
          const SectionHeader('Door rules'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                value: gym.settings.blockExpiredAtDoor,
                onChanged: (v) => gym.updateSettings(gym.settings.copyWith(blockExpiredAtDoor: v)),
                title: const Text('Block expired and frozen members'),
                subtitle: const Text('The door refuses them until they renew. Their face stays saved.'),
              ),
              SwitchListTile(
                value: gym.settings.blockDuesAtDoor,
                onChanged: (v) => gym.updateSettings(gym.settings.copyWith(blockDuesAtDoor: v)),
                title: const Text('Block members with unpaid dues'),
                subtitle: const Text('Off by default. Turn on to make the door ask for payment first.'),
              ),
              SwitchListTile(
                value: gym.settings.syncDeviceClock,
                onChanged: (v) => gym.updateSettings(gym.settings.copyWith(syncDeviceClock: v)),
                title: const Text('Keep the device clock right'),
                subtitle: const Text('Sets its time from this phone on every sync, so entry times are correct.'),
              ),
            ]),
          ),
          SectionHeader('Not registered yet · ${notRegistered.length}'),
          if (notRegistered.isEmpty)
            const AppCard(child: Text('Every member with a running plan has Face ID.', style: AppText.bodyMuted))
          else
            for (final m in notRegistered.take(20))
              MemberTile(
                member: m,
                subtitle: m.deviceUserId == null ? 'Not on the device' : 'On the device (ID ${m.deviceUserId}), face not confirmed',
                trailing: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: () => showFaceIdSheet(context, m),
                  child: const Text('Register'),
                ),
              ),
          if (blocked.isNotEmpty) ...[
            SectionHeader('Blocked at the door · ${blocked.length}'),
            for (final m in blocked.take(15))
              MemberTile(
                member: m,
                subtitle: 'Device ID ${m.deviceUserId} · ${gym.statusOf(m) == MemberStatus.frozen ? 'frozen' : (gym.daysLeft(m) < 0 ? 'plan ended' : 'unpaid dues')}',
                trailing: const Icon(AppIcons.block, color: AppColors.danger),
              ),
          ],
          const SectionHeader('Members already on the device'),
          AppCard(
            onTap: device.busy ? null : () => _showLinkSheet(context),
            child: Row(children: [
              const IconBadge(AppIcons.link, color: AppColors.seriesCompare),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Match device users to members', style: AppText.title.copyWith(fontSize: 15.5)),
                  Text('For faces enrolled before the app. Names are matched for you.', style: AppText.small.copyWith(color: AppColors.muted)),
                ]),
              ),
              const Icon(AppIcons.chevronRight, color: AppColors.muted),
            ]),
          ),
          if (!device.isDemo && device.configured) ...[
            const SectionHeader('Connection'),
            const _ConnectionForm(),
          ],
          const SizedBox(height: 18),
          Text(
            'Works with eSSL and ZKTeco face terminals on the same Wi-Fi as this phone. Tap ? at the top for the step-by-step setup guide.',
            style: AppText.small.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

void _openGuide(BuildContext context) => openPage(context, FaceIdSetupGuide(onOpenConnection: () => Navigator.pop(context)));

/// Shown until the terminal is connected: what to do first, with the guide one tap away.
class _FirstTimeCard extends StatelessWidget {
  final VoidCallback onGuide;

  const _FirstTimeCard({required this.onGuide});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(AppIcons.rocket, color: AppColors.primaryBright),
          const SizedBox(width: 12),
          Expanded(child: Text('First-time setup', style: AppText.headline.copyWith(fontSize: 20))),
        ]),
        const SizedBox(height: 10),
        Text(
          'The Face ID door is not connected yet. You need its IP address from the terminal menu (Menu > Comm. > Ethernet), and this tablet on the same Wi-Fi. The guide walks through it in 7 short steps.',
          style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onGuide, icon: const Icon(AppIcons.guide), label: const Text('Open setup guide'))),
      ]),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero();

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final ok = device.configured && device.error == null;
    final linked = gym.members.where((m) => m.deviceUserId != null).length;
    final info = device.lastInfo;
    Widget dot = Container(width: 10, height: 10, decoration: BoxDecoration(color: ok ? AppColors.success : AppColors.warning, shape: BoxShape.circle));
    if (ok && !Motion.reduced(context)) {
      dot = dot.animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(begin: 1, duration: 900.ms).scaleXY(end: 0.6, duration: 900.ms);
    }
    return AppCard(
      gradient: AppColors.redGradient,
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(width: 10, height: 10, child: dot),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                !device.configured ? 'Not set up' : (device.error != null ? 'Cannot reach the device' : syncAgo(gym.settings.lastDeviceSync, gym.now)),
                style: AppText.small.copyWith(color: Colors.white70),
              ),
            ),
            const Icon(AppIcons.faceId, color: Colors.white70, size: 30),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CountUp(value: linked, style: AppText.display.copyWith(fontSize: 52, height: 0.95, color: Colors.white)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Members linked\nto Face ID', style: AppText.label.copyWith(color: Colors.white70, height: 1.3)),
            ),
            const Spacer(),
            if (info != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${info.faces} faces', style: AppText.headline.copyWith(fontSize: 20, color: Colors.white)),
                Text('${info.records} door entries stored', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
          ]),
          if (device.error != null) ...[
            const SizedBox(height: 10),
            Text(device.error!, style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDeep),
                onPressed: !device.configured || device.busy
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        try {
                          await device.sync();
                        } catch (_) {/* shown on the card */}
                      },
                icon: device.busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primaryDeep))
                    : const Icon(AppIcons.sync),
                label: Text(device.busy ? 'Syncing' : 'Sync now'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.transparent, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 54)),
              onPressed: !device.configured || device.busy
                  ? null
                  : () async {
                      try {
                        final i = await device.test();
                        if (context.mounted) showMessage(context, 'Connected: ${i.users} users and ${i.faces} faces on the device.');
                      } catch (_) {/* shown on the card */}
                    },
              child: const Text('Test'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SyncReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label, Color color) => Expanded(
          child: Column(children: [
            Text(value, style: AppText.headline.copyWith(fontSize: 24, color: color)),
            Text(label, textAlign: TextAlign.center, style: AppText.label.copyWith(fontSize: 9)),
          ]),
        );
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(children: [
        stat('${report.imported}', 'New entries', AppColors.success),
        stat('${report.blocked}', 'Blocked', AppColors.danger),
        stat('${report.unblocked}', 'Allowed again', AppColors.seriesCompare),
        stat('${report.unknownIds}', 'Unknown IDs', AppColors.muted),
      ]),
    );
  }
}

class _ConnectionForm extends StatefulWidget {
  const _ConnectionForm();

  @override
  State<_ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<_ConnectionForm> {
  late final GymProvider _gym = context.read<GymProvider>();
  late final _host = TextEditingController(text: _gym.settings.deviceHost);
  late final _port = TextEditingController(text: '${_gym.settings.devicePort}');
  late final _key = TextEditingController(text: _gym.settings.deviceCommKey == 0 ? '' : '${_gym.settings.deviceCommKey}');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(controller: _host, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Device IP address', hintText: 'e.g. 192.168.1.201', prefixIcon: Icon(AppIcons.router))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _key, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Comm key', hintText: 'blank = none'))),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              await _gym.updateSettings(_gym.settings.copyWith(
                deviceHost: _host.text.trim(),
                devicePort: int.tryParse(_port.text.trim()) ?? 4370,
                deviceCommKey: int.tryParse(_key.text.trim()) ?? 0,
              ));
              if (!context.mounted) return;
              final device = context.read<DeviceService>();
              try {
                final i = await device.test();
                if (context.mounted) showMessage(context, 'Connected: ${i.users} users, ${i.faces} faces.');
              } catch (_) {
                if (context.mounted) {
                  showMessage(context, device.error ?? 'Could not reach the device.', actionLabel: 'Guide', onAction: () => _openGuide(context));
                }
              }
            },
            child: const Text('Save and test'),
          ),
        ),
      ]),
    );
  }
}

/// Lists users on the device that are not linked yet, each with the best matching member.
Future<void> _showLinkSheet(BuildContext context) async {
  final device = context.read<DeviceService>();
  final List<ZkUser> users;
  try {
    users = await device.deviceUsers();
  } catch (_) {
    if (context.mounted) showMessage(context, device.error ?? 'Could not reach the device.');
    return;
  }
  if (!context.mounted) return;
  await showAppSheet<void>(context, builder: (_) => _LinkSheet(users: users));
}

class _LinkSheet extends StatelessWidget {
  final List<ZkUser> users;

  const _LinkSheet({required this.users});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.read<DeviceService>();
    final unlinked = users.where((u) => gym.memberByDeviceId(u.userId) == null).toList();
    final free = gym.members.where((m) => m.deviceUserId == null).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(children: [
          SheetHeader('Match device users', subtitle: '${unlinked.length} people on the device are not linked to a member.'),
          Expanded(
            child: unlinked.isEmpty
                ? const EmptyState(icon: AppIcons.taskDone, title: 'All matched', subtitle: 'Every person on the device is linked to a member.')
                : ListView.builder(
                    itemCount: unlinked.length,
                    itemBuilder: (context, i) {
                      final u = unlinked[i];
                      Member? best;
                      var score = 0.0;
                      for (final m in free) {
                        final s = nameMatch(u.name, m.name);
                        if (s > score) {
                          score = s;
                          best = m;
                        }
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            CircleAvatar(backgroundColor: AppColors.surfaceHigher, child: Text(u.userId, style: AppText.small.copyWith(color: AppColors.text, fontSize: 11))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(u.name, style: AppText.title.copyWith(fontSize: 15)),
                                Text(best == null || score < 0.5 ? 'No close match' : 'Looks like ${best.name}', style: AppText.small.copyWith(color: score >= 0.5 ? AppColors.success : AppColors.muted)),
                              ]),
                            ),
                            TextButton(
                              onPressed: () async {
                                final pick = score >= 0.5 ? best : await _pickMember(context, free);
                                if (pick != null) await device.link(pick, u);
                              },
                              child: Text(score >= 0.5 ? 'Link' : 'Choose'),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Future<Member?> _pickMember(BuildContext context, List<Member> members) => showAppSheet<Member>(
        context,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 18), children: [
            const SheetHeader('Which member is this?'),
            for (final m in members) MemberTile(member: m, onTap: () => Navigator.pop(sheetContext, m)),
          ]),
        ),
      );
}
