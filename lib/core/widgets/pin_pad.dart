import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/gym_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/motion.dart';
import 'sub_page.dart';

/// Four dots and a number pad. Calls [onComplete] with the 4 digits; return false from it to shake
/// the dots and clear (wrong PIN).
class PinPad extends StatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function(String pin) onComplete;

  const PinPad({super.key, required this.title, required this.subtitle, required this.onComplete});

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  Future<void> _press(String key) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (key == '⌫') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin += key);
    if (_pin.length == 4) {
      _busy = true;
      final ok = await widget.onComplete(_pin);
      if (!mounted) return;
      if (!ok) {
        HapticFeedback.heavyImpact();
        await _shake.forward(from: 0);
        if (!mounted) return;
        setState(() => _pin = '');
      }
      _busy = false;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_rounded, color: AppColors.primaryBright, size: 30),
        const SizedBox(height: 10),
        Text(widget.title.toUpperCase(), style: AppText.headline, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(widget.subtitle, style: AppText.bodyMuted, textAlign: TextAlign.center),
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(offset: Offset(math.sin(_shake.value * math.pi * 6) * 12 * (1 - _shake.value), 0), child: child),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++)
                AnimatedContainer(
                  duration: Motion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: i < _pin.length ? AppColors.primary : AppColors.borderStrong, width: 2),
                    boxShadow: i < _pin.length ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 10)] : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final key in row)
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: key.isEmpty
                      ? const SizedBox(width: 72, height: 60)
                      : Material(
                          color: AppColors.surfaceHigh,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _press(key),
                            child: SizedBox(
                              width: 72,
                              height: 60,
                              child: Center(
                                child: key == '⌫'
                                    ? const Icon(Icons.backspace_outlined, color: AppColors.textSecondary, semanticLabel: 'Delete')
                                    : Text(key, style: AppText.headline.copyWith(fontStyle: FontStyle.normal, fontSize: 26)),
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Returns true when owner areas are open, asking for the PIN first if they are locked.
Future<bool> ensureOwner(BuildContext context, {String reason = 'Revenue, expenses and settings are for the owner.'}) async {
  final gym = context.read<GymProvider>();
  if (gym.ownerUnlocked) return true;
  final ok = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: PinPad(
        title: 'Owner PIN',
        subtitle: reason,
        onComplete: (pin) async {
          final ok = gym.unlock(pin);
          if (ok && sheetContext.mounted) Navigator.pop(sheetContext, true);
          return ok;
        },
      ),
    ),
  );
  return ok ?? false;
}

/// Asks for a new PIN twice and saves it. Returns true when a PIN was set.
Future<bool> showSetPinSheet(BuildContext context) async {
  final gym = context.read<GymProvider>();
  String? first;
  final ok = await showAppSheet<bool>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: PinPad(
          key: ValueKey(first == null),
          title: first == null ? 'New owner PIN' : 'Confirm PIN',
          subtitle: first == null ? 'Choose 4 digits. Staff will need it to see revenue or change settings.' : 'Enter the same 4 digits again.',
          onComplete: (pin) async {
            if (first == null) {
              setState(() => first = pin);
              return true;
            }
            if (pin != first) {
              setState(() => first = null);
              return false;
            }
            await gym.setPin(pin);
            if (sheetContext.mounted) Navigator.pop(sheetContext, true);
            return true;
          },
        ),
      ),
    ),
  );
  return ok ?? false;
}
