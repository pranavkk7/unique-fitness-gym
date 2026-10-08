import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../device/device_service.dart';
import '../../providers/gym_provider.dart';

/// First-time setup of the eSSL Face ID terminal, step by step, written for the front desk.
/// Menu names differ slightly between eSSL models, so each step names the usual alternatives.
class FaceIdSetupGuide extends StatelessWidget {
  /// Opens the connection form when the guide reaches "enter the details".
  final VoidCallback? onOpenConnection;

  const FaceIdSetupGuide({super.key, this.onOpenConnection});

  static const _steps = <({IconData icon, String title, String body, List<String> points, String? tip})>[
    (
      icon: Icons.checklist_rounded,
      title: 'Before you start',
      body: 'You need three things:',
      points: [
        'The Face ID terminal switched on and connected to the gym router with a LAN cable (or its own Wi-Fi).',
        'This phone or tablet on the same Wi-Fi as that router. A guest Wi-Fi will not work.',
        'The terminal\'s admin password, if a menu password is set.',
      ],
      tip: 'Safety first: back up the terminal once. On the device: Menu > Data Mgt. > Backup Data (to a USB stick).',
    ),
    (
      icon: Icons.router_rounded,
      title: 'Find the terminal\'s IP address',
      body: 'On the Face ID terminal:',
      points: [
        'Press Menu (M/OK) and log in as admin.',
        'Open Comm. (or Communication / Network) > Ethernet (or TCP/IP).',
        'Write down the IP Address, for example 192.168.1.201.',
      ],
      tip: 'Set DHCP to OFF and keep this IP fixed. Otherwise the address can change after a power cut and the app loses the door.',
    ),
    (
      icon: Icons.vpn_key_rounded,
      title: 'Check the port and Comm Key',
      body: 'Still in Comm.:',
      points: [
        'Open PC Connection (or Comm. Key / Connection).',
        'The port is usually 4370.',
        'The Comm Key (device password) is usually 0, which means none. If someone set one, note it down.',
      ],
      tip: null,
    ),
    (
      icon: Icons.edit_note_rounded,
      title: 'Enter the details in this app',
      body: 'On the Face ID device page, under Connection:',
      points: [
        'Type the IP address, the port (4370) and the Comm Key (leave it blank if it is 0).',
        'Tap SAVE AND TEST.',
        'When it works, the app shows how many users and faces are on the terminal.',
      ],
      tip: null,
    ),
    (
      icon: Icons.link_rounded,
      title: 'Link the members who already use the door',
      body: 'Faces enrolled before this app are already on the terminal:',
      points: [
        'Tap Match device users to members.',
        'The app suggests a member for each name on the device. Tap Link when it is right, or Choose to pick the member.',
        'Do this before switching on Block expired members, so nobody is blocked by mistake.',
      ],
      tip: null,
    ),
    (
      icon: Icons.sync_rounded,
      title: 'Run the first sync',
      body: 'Tap SYNC NOW at the top of the Face ID page:',
      points: [
        'Door entries come into the app as check-ins (the first sync reads up to 60 days).',
        'Expired or frozen members are blocked at the door, if that rule is on.',
        'After this the app syncs by itself every 5 minutes while it is open.',
      ],
      tip: null,
    ),
    (
      icon: Icons.face_retouching_natural_rounded,
      title: 'New members from now on',
      body: 'After an admission, tap FACE ID (or Add Face ID on the profile):',
      points: [
        'The app adds the member to the terminal and shows their device ID.',
        'On the terminal: Menu > User Mgt. > find that ID > Face, and the member looks at the camera for a few seconds.',
        'The app notices the new face and marks it registered. If it does not, tap FACE IS ADDED ON THE DEVICE.',
      ],
      tip: null,
    ),
  ];

  static const _problems = <(String, String)>[
    (
      'Cannot reach the device',
      'Check that the phone is on the gym Wi-Fi (not mobile data or a guest network), that the IP is typed correctly, and that the terminal shows a network icon. Restart the router and the terminal if needed.',
    ),
    (
      'It worked yesterday, not today',
      'The IP probably changed after a power cut. Find it again (step 2), set DHCP to OFF, and update it in the app.',
    ),
    ('Wrong Comm Key', 'The key in the app must match the terminal exactly. Check Comm. > PC Connection on the device.'),
    (
      'Connected but nothing syncs',
      'Close eTimeTrackLite or any other attendance software on the office PC: most terminals talk to one program at a time.',
    ),
    (
      'Router setting to check',
      'If the Wi-Fi has "AP isolation" or "client isolation" switched on, devices cannot see each other. Turn it off for the gym network.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final connected = device.configured && !device.isDemo && device.error == null && gym.settings.lastDeviceSync != null;
    return SubPage(
      title: 'Face ID setup',
      subtitle: 'First-time connection · about 10 minutes',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          AppCard(
            gradient: AppColors.redGradient,
            glow: true,
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  connected
                      ? 'Connected. Come back here any time a new staff member needs to set it up again.'
                      : 'Connect the gym\'s eSSL Face ID door once. After that, members are added to the door from the app and their entries arrive as check-ins.',
                  style: AppText.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ]),
          ).entrance(context),
          if (device.isDemo)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderColor: AppColors.warning.withValues(alpha: 0.35),
                child: Text('Demo data is loaded, so a simulated door is used. Erase the demo data in Settings before connecting the real terminal.', style: AppText.small.copyWith(color: AppColors.warning)),
              ),
            ),
          const SizedBox(height: 6),
          for (var i = 0; i < _steps.length; i++) _Step(number: i + 1, step: _steps[i], last: i == _steps.length - 1).entrance(context, index: i + 1),
          if (onOpenConnection != null && !device.isDemo) ...[
            const SizedBox(height: 4),
            FilledButton.icon(onPressed: onOpenConnection, icon: const Icon(Icons.router_rounded), label: const Text('ENTER THE DEVICE DETAILS')),
          ],
          const SectionHeader('If something goes wrong'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (title, fix) in _problems)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: const Icon(Icons.help_outline_rounded, color: AppColors.warning),
                    title: Text(title, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                    childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(fix, style: AppText.small.copyWith(color: AppColors.textSecondary, height: 1.4))],
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            'Works with eSSL and ZKTeco face terminals that support PC connection on port 4370 (for example the eSSL uFace, iFace and SpeedFace series).',
            style: AppText.small.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final ({IconData icon, String title, String body, List<String> points, String? tip}) step;
  final bool last;

  const _Step({required this.number, required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // The numbered rail on the left, joined from step to step.
        SizedBox(
          width: 44,
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: AppColors.redGradient, shape: BoxShape.circle),
              child: Text('$number', style: AppText.headline.copyWith(fontSize: 17, color: Colors.white)),
            ),
            if (!last) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.borderStrong)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(step.icon, size: 20, color: AppColors.primaryBright),
                  const SizedBox(width: 8),
                  Expanded(child: Text(step.title, style: AppText.title.copyWith(fontSize: 16))),
                ]),
                const SizedBox(height: 6),
                Text(step.body, style: AppText.small.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                for (final p in step.points)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 6, color: AppColors.primaryBright)),
                      Expanded(child: Text(p, style: AppText.body.copyWith(fontSize: 14.5, height: 1.35))),
                    ]),
                  ),
                if (step.tip != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(step.tip!, style: AppText.small.copyWith(color: AppColors.warning, height: 1.35))),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
