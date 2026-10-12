import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/skin.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';

/// Choose how the app looks. Both designs have every feature; the choice is saved on this device.
class DesignScreen extends StatelessWidget {
  const DesignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the page from scratch when the design changes, so it shows the new look at once.
    return ValueListenableBuilder<AppSkin>(
      valueListenable: Skin.notifier,
      builder: (context, current, _) => KeyedSubtree(
        key: ValueKey(current),
        child: SubPage(
          title: 'Design',
          subtitle: 'Saved on this device',
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Text('Pick the look you like working with. Everything works the same in both.', style: AppText.bodyMuted),
              const SizedBox(height: 18),
              for (final skin in AppSkin.values) ...[
                _DesignOption(skin: skin, selected: skin == current),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DesignOption extends StatelessWidget {
  final AppSkin skin;
  final bool selected;

  const _DesignOption({required this.skin, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${skin.label} design. ${skin.description}',
      excludeSemantics: true,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        borderColor: selected ? AppColors.ink : null,
        onTap: selected
            ? null
            : () {
                HapticFeedback.selectionClick();
                Skin.set(skin);
              },
        child: Row(children: [
          _Preview(skin: skin),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(skin.label, style: AppText.title),
              const SizedBox(height: 4),
              Text(skin.description, style: AppText.small.copyWith(color: AppColors.muted)),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: Motion.fast,
                child: selected
                    ? Row(key: const ValueKey('on'), mainAxisSize: MainAxisSize.min, children: [
                        Icon(AppIcons.checkCircle, size: 18, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text('In use', style: AppText.small.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ])
                    : Text('Tap to use', key: const ValueKey('off'), style: AppText.small.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A small drawing of each design's home screen, in that design's own colours and type, so the
/// choice can be seen before it is made.
class _Preview extends StatelessWidget {
  final AppSkin skin;

  const _Preview({required this.skin});

  @override
  Widget build(BuildContext context) {
    final classic = skin == AppSkin.classic;
    final page = classic ? const Color(0xFF09090B) : const Color(0xFFEDEFEB);
    final sheet = classic ? const Color(0xFF141418) : Colors.white;
    final ink = classic ? const Color(0xFFF5F5F7) : const Color(0xFF1B1D21);
    final edge = classic ? const Color(0x14FFFFFF) : const Color(0xFFDDE0DA);
    final number = TextStyle(
      fontFamily: classic ? 'BarlowCondensed' : 'ArchivoExpanded',
      fontStyle: classic ? FontStyle.italic : FontStyle.normal,
      fontWeight: classic ? FontWeight.w900 : FontWeight.w700,
      fontSize: 22,
      height: 1,
      color: classic ? Colors.white : ink,
    );
    Widget bar(double w, Color c) => Container(width: w, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));

    return Container(
      width: 96,
      height: 132,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: edge),
        gradient: classic
            ? const RadialGradient(center: Alignment(0.9, -1), radius: 1.1, colors: [Color(0x55F0262E), Color(0xFF09090B)])
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bar(40, ink.withValues(alpha: 0.8)),
        const SizedBox(height: 8),
        // The day's summary card: a red gradient in Classic, a white sheet in Plate & Chalk.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: classic ? null : sheet,
            gradient: classic ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3B3B), Color(0xFFD9141C), Color(0xFF8E0008)]) : null,
            borderRadius: BorderRadius.circular(classic ? 9 : 6),
            border: classic ? null : Border.all(color: edge),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('46', style: number),
            const SizedBox(height: 5),
            // Door ticks.
            SizedBox(
              height: 8,
              child: Row(children: [
                for (var i = 0; i < 14; i++) ...[
                  Container(width: 1.4, height: const <double>[4, 7, 5, 8, 3, 6, 8, 4, 7, 5, 3, 8, 6, 4][i], color: classic ? Colors.white.withValues(alpha: 0.85) : ink),
                  const SizedBox(width: 2.6),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(
              child: Container(
                height: 26,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: sheet, borderRadius: BorderRadius.circular(classic ? 7 : 5), border: Border.all(color: edge)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: classic
                      ? Container(width: 9, height: 9, decoration: BoxDecoration(color: (i == 0 ? const Color(0xFF2FD07F) : const Color(0xFFFFB020)).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)))
                      : bar(18, ink.withValues(alpha: 0.35)),
                ),
              ),
            ),
            if (i == 0) const SizedBox(width: 5),
          ],
        ]),
        const Spacer(),
        // The bottom bar and its check-in key.
        Center(
          child: Container(
            width: classic ? 18 : 20,
            height: classic ? 18 : 12,
            decoration: BoxDecoration(
              color: classic ? const Color(0xFFF0262E) : ink,
              shape: classic ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: classic ? null : BorderRadius.circular(4),
              boxShadow: classic ? const [BoxShadow(color: Color(0x88F0262E), blurRadius: 8)] : null,
            ),
          ),
        ),
      ]),
    );
  }
}
