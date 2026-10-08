import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/contact.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/member_widgets.dart';
import '../../models/models.dart';
import '../../providers/gym_provider.dart';

/// "Send all": walks through a reminder list one person at a time. Each tap opens WhatsApp with
/// the message ready, logs it as sent and brings up the next person, so a whole list takes a
/// minute. (Fully automatic sending needs the WhatsApp Business API; see the README roadmap.)
Future<void> runReminderQueue(BuildContext context, ReminderKind kind) {
  final targets = context.read<GymProvider>().reminderQueue(kind);
  if (targets.isEmpty) return Future.value();
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black54,
    transitionDuration: Motion.medium,
    pageBuilder: (_, _, _) => _Runner(kind: kind, targets: targets),
    transitionsBuilder: (_, a, _, child) => SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Motion.settle)), child: FadeTransition(opacity: a, child: child)),
  ));
}

class _Runner extends StatefulWidget {
  final ReminderKind kind;
  final List<ReminderTarget> targets;

  const _Runner({required this.kind, required this.targets});

  @override
  State<_Runner> createState() => _RunnerState();
}

class _RunnerState extends State<_Runner> {
  int _index = 0;
  int _sent = 0;
  bool _forward = true;

  bool get _finished => _index >= widget.targets.length;

  Future<void> _send() async {
    final t = widget.targets[_index];
    final gym = context.read<GymProvider>();
    final ok = await openWhatsApp(context, t.phone, t.message);
    if (!mounted) return;
    if (ok) {
      await gym.logReminder(t.kind, t.id);
      _sent++;
    }
    _advance();
  }

  void _advance() => setState(() {
        _forward = true;
        _index++;
      });

  void _back() {
    if (_index == 0) return;
    setState(() {
      _forward = false;
      _index--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.targets.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.borderStrong)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(children: [
                      Icon(widget.kind.icon, color: widget.kind.color),
                      const SizedBox(width: 10),
                      Expanded(child: Text(widget.kind.label.toUpperCase(), style: AppText.headline.copyWith(fontSize: 20))),
                      Text(_finished ? '$total of $total' : '${_index + 1} of $total', style: AppText.small.copyWith(color: AppColors.muted)),
                      IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _index / total),
                      duration: Motion.medium,
                      curve: Motion.settle,
                      builder: (context, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: v, minHeight: 5, color: AppColors.whatsapp, backgroundColor: AppColors.surfaceHigher),
                      ),
                    ),
                  ),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      switchInCurve: Motion.settle,
                      transitionBuilder: (child, a) {
                        final incoming = child.key == ValueKey(_index);
                        final dx = incoming == _forward ? 0.25 : -0.25;
                        return FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(a), child: child));
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _finished ? _Done(sent: _sent, total: total) : _Card(target: widget.targets[_index]),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: _finished
                        ? SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('DONE')))
                        : Row(children: [
                            IconButton(tooltip: 'Previous', onPressed: _index == 0 ? null : _back, icon: const Icon(Icons.chevron_left_rounded)),
                            TextButton(onPressed: _advance, child: const Text('Skip')),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: AppColors.whatsapp, foregroundColor: Colors.black),
                                onPressed: _send,
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('SEND'),
                              ),
                            ),
                          ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final ReminderTarget target;

  const _Card({required this.target});

  @override
  Widget build(BuildContext context) {
    final m = target.member;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        children: [
          if (m != null)
            MemberAvatar(member: m, size: 84, hero: false)
          else
            CircleAvatar(radius: 42, backgroundColor: AppColors.surfaceHigher, child: Text(initials(target.name), style: AppText.headline)),
          const SizedBox(height: 12),
          Text(target.name.toUpperCase(), style: AppText.display.copyWith(fontSize: 28), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${target.phone} · ${target.detail}', style: AppText.small.copyWith(color: target.kind.color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // The message as it will look in WhatsApp.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFF005C4B),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(4), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Text(target.message, style: AppText.body.copyWith(color: Colors.white, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  final int sent;
  final int total;

  const _Done({required this.sent, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SuccessBurst(size: 130),
        Text(sent == total ? 'ALL $total SENT' : '$sent OF $total SENT', style: AppText.display.copyWith(fontSize: 32)),
        const SizedBox(height: 6),
        Text(sent == total ? 'Everyone on this list has their reminder.' : 'Skipped people stay on the list for later.', style: AppText.bodyMuted, textAlign: TextAlign.center),
      ]),
    );
  }
}

