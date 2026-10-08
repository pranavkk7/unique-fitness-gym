import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/motion.dart';
import '../utils/format.dart';
import 'surfaces.dart';

/// A section heading in sentence case, with an optional link on the right.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding = const EdgeInsets.fromLTRB(2, 28, 2, 10)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: AppText.headline.copyWith(fontSize: 16.5))),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// The signature mark: a weight plate seen face-on, a ring with a hole in the middle. Shown in a
/// plate colour for state (green active, yellow ending soon, red expired or owing, blue frozen).
class PlateRing extends StatelessWidget {
  final Color color;
  final double size;

  const PlateRing({super.key, required this.color, this.size = 12});

  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _PlatePainter(color)));
}

class _PlatePainter extends CustomPainter {
  final Color color;

  _PlatePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r * 0.68, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.64..color = color);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.color != color;
}

/// State as a plate ring and a word, never colour alone. [icon] is accepted for older callers but the
/// ring carries the meaning.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusPill(this.label, {super.key, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlateRing(color: color, size: 11),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A number that counts to its value when shown, and from the old value to the new one when it changes.
class CountUp extends StatelessWidget {
  final num value;
  final String Function(num) format;
  final TextStyle? style;
  final Duration duration;

  /// Static by default; pass a [duration] where counting up is the point (the dashboard's one moment).
  const CountUp({super.key, required this.value, this.format = _plain, this.style, this.duration = Duration.zero});

  static String _plain(num v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final text = style ?? AppText.stat;
    if (Motion.reduced(context) || duration == Duration.zero) return Text(format(value), style: text);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text(format(v), style: text),
    );
  }
}

/// "+12%" in green or "-4%" in red, for changes against an earlier period.
class ChangeChip extends StatelessWidget {
  final double? change;
  final String? suffix;
  final bool onRed; // drawn on the iron panel, so use white instead of plate colours

  const ChangeChip(this.change, {super.key, this.suffix, this.onRed = false});

  @override
  Widget build(BuildContext context) {
    final c = change;
    if (c == null) return const SizedBox.shrink();
    final up = c >= 0;
    final color = onRed ? Colors.white : (up ? AppColors.success : AppColors.danger);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? AppIcons.trendUp : AppIcons.trendDown, size: 15, color: color),
        const SizedBox(width: 4),
        Text('${formatChange(c)}${suffix == null ? '' : ' $suffix'}', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(title, style: AppText.headline, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: AppText.bodyMuted, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ).entrance(context),
    );
  }
}

/// Icon, label and value in one row, for detail cards.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.muted),
          const SizedBox(width: 12),
          SizedBox(width: 104, child: Text(label, style: AppText.bodyMuted)),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: AppText.body.copyWith(fontWeight: FontWeight.w600))),
          ?trailing,
        ],
      ),
    );
  }
}

/// A figure with its caption, for dashboard grids: the number does the talking.
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget value;
  final String? caption;
  final VoidCallback? onTap;

  /// A small trend drawn beside the number.
  final Widget? chart;

  const StatTile({super.key, required this.icon, required this.color, required this.label, required this.value, this.caption, this.onTap, this.chart});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (onTap != null) const Icon(AppIcons.chevronRight, size: 15, color: AppColors.muted),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value)),
              if (chart != null) ...[const SizedBox(width: 8), SizedBox(width: 56, height: 28, child: chart)],
            ]),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(caption!, style: AppText.small.copyWith(color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows "₹ • • • •" with a lock while owner areas are locked, otherwise [child].
class LockedValue extends StatelessWidget {
  final bool locked;
  final Widget child;
  final TextStyle? style;

  const LockedValue({super.key, required this.locked, required this.child, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: locked
          ? Row(
              key: const ValueKey('locked'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹ ••••', style: style ?? AppText.stat),
                const SizedBox(width: 6),
                const Icon(AppIcons.lock, size: 16, color: AppColors.muted),
              ],
            )
          : KeyedSubtree(key: const ValueKey('open'), child: child),
    );
  }
}

/// A small card with a caption and one big figure, used in rows of three. Figures are ink;
/// only a red [color] (money owed, a problem) is kept.
class FigureCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const FigureCard(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.label.copyWith(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: AppText.headline.copyWith(fontSize: 20, color: color == AppColors.danger ? color : AppColors.text))),
        ]),
      );
}
