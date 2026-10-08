import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/pin_pad.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../device/device_service.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';
import 'device_screen.dart';
import 'face_scan.dart';

/// Face ID for one member: register them on the door terminal, or see and manage their status.
Future<void> showFaceIdSheet(BuildContext context, Member member) {
  final device = context.read<DeviceService>();
  if (!device.configured) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SheetHeader('Face ID not set up', subtitle: 'Connect the app to the gym\'s eSSL Face ID device once. Then members can be registered from here.'),
          FilledButton(
            onPressed: () async {
              Navigator.pop(sheetContext);
              if (await ensureOwner(context) && context.mounted) openPage(context, const DeviceScreen());
            },
            child: const Text('SET UP THE DEVICE'),
          ),
        ]),
      ),
    );
  }
  final linked = member.deviceUserId != null;
  return showAppSheet<void>(context, builder: (_) => linked && member.faceEnrolled ? _FaceStatus(memberId: member.id) : _FaceRegister(memberId: member.id));
}

class _FaceRegister extends StatefulWidget {
  final String memberId;

  const _FaceRegister({required this.memberId});

  @override
  State<_FaceRegister> createState() => _FaceRegisterState();
}

class _FaceRegisterState extends State<_FaceRegister> {
  FaceStage _stage = FaceStage.connecting;
  String? _deviceId;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final gym = context.read<GymProvider>();
    final device = context.read<DeviceService>();
    final member = gym.memberById(widget.memberId)!;
    setState(() {
      _stage = FaceStage.connecting;
      _cancelled = false;
    });
    final ok = await device.registerFace(
      member,
      cancelled: () => _cancelled || !mounted,
      onStage: (stage, id) {
        if (!mounted) return;
        if (stage == FaceStage.done) HapticFeedback.heavyImpact();
        setState(() {
          _stage = stage;
          _deviceId = id ?? _deviceId;
        });
      },
    );
    if (!ok && mounted && _stage != FaceStage.failed && !_cancelled) setState(() => _stage = FaceStage.waitingForFace);
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.watch<DeviceService>();
    final member = gym.memberById(widget.memberId)!;
    final done = _stage == FaceStage.done;
    final failed = _stage == FaceStage.failed;
    final (title, sub) = switch (_stage) {
      FaceStage.connecting => ('Connecting', 'Reaching the Face ID device on the gym Wi-Fi…'),
      FaceStage.adding => ('Adding ${member.firstName}', 'Creating their entry on the device…'),
      FaceStage.waitingForFace => ('Look at the device', 'On the device: Menu > User Mgt > find ID ${_deviceId ?? ''} > Face. ${member.firstName} looks at the camera for a few seconds.'),
      FaceStage.done => ('Face registered', '${member.firstName} can walk in with Face ID now. Device ID ${_deviceId ?? ''}.'),
      FaceStage.failed => ('Could not reach the device', device.error ?? 'Check that this phone is on the gym Wi-Fi.'),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                child: failed
                    ? const SuccessBurst(key: ValueKey('fail'), kind: BurstKind.error, size: 150)
                    : done
                        ? const SuccessBurst(key: ValueKey('ok'), size: 170)
                        : FaceScan(key: const ValueKey('scan'), scanning: _stage == FaceStage.waitingForFace),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: Text(title.toUpperCase(), key: ValueKey(title), textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 30)),
            ),
            const SizedBox(height: 8),
            Text(sub, textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)),
            if (_stage == FaceStage.waitingForFace) ...[
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Text('Waiting for the device to confirm the face', style: AppText.small.copyWith(color: AppColors.muted)),
              ]),
            ],
            const SizedBox(height: 18),
            if (done)
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('DONE'))
            else if (failed)
              FilledButton(onPressed: _start, child: const Text('TRY AGAIN'))
            else if (_stage == FaceStage.waitingForFace)
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () async {
                  // Some models do not report face counts; staff can confirm by hand.
                  await device.confirmFace(gym.memberById(widget.memberId)!);
                  if (mounted) setState(() => _stage = FaceStage.done);
                },
                child: const Text('FACE IS ADDED ON THE DEVICE'),
              ),
            TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.pop(context);
              },
              child: Text(done ? 'Close' : 'Do it later'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceStatus extends StatelessWidget {
  final String memberId;

  const _FaceStatus({required this.memberId});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final device = context.read<DeviceService>();
    final m = gym.memberById(memberId)!;
    final allowed = gym.doorAccessAllowed(m);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader('Face ID · ${m.firstName}', subtitle: 'Device ID ${m.deviceUserId}'),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.face_retouching_natural_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Face registered on the device', style: AppText.body)),
                  const StatusPill('Enrolled', color: AppColors.success, icon: Icons.check_rounded),
                ]),
                const Divider(height: 22),
                Row(children: [
                  Icon(allowed ? Icons.door_front_door_rounded : Icons.block_rounded, color: allowed ? AppColors.success : AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(allowed ? 'Door opens for them' : 'Blocked at the door until they renew', style: AppText.body)),
                  StatusPill(allowed ? 'Allowed' : 'Blocked', color: allowed ? AppColors.success : AppColors.danger),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            Text('The app updates the device on every sync: blocked when the plan ends, allowed again the moment they renew.', style: AppText.small.copyWith(color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final r = await device.sync();
                  if (context.mounted) showMessage(context, 'Synced: ${r.imported} new entries, ${r.blocked} blocked, ${r.unblocked} allowed again.');
                } catch (_) {
                  if (context.mounted) showMessage(context, device.error ?? 'Could not reach the device.');
                }
              },
              icon: const Icon(Icons.sync_rounded),
              label: const Text('SYNC WITH DEVICE'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                if (!await ensureOwner(context, reason: 'Removing a face from the device needs the owner PIN.') || !context.mounted) return;
                final ok = await confirmAction(context, title: 'Remove from device?', message: '${m.firstName}\'s face is deleted from the door device. They would need to register again.', confirmLabel: 'Remove');
                if (!ok || !context.mounted) return;
                try {
                  await device.removeFromDevice(m);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted) showMessage(context, device.error ?? 'Could not reach the device.');
                }
              },
              child: const Text('Remove from the device'),
            ),
          ],
        ),
      ),
    );
  }
}
