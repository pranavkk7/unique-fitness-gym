import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';

/// Page background. Plate & Chalk: plain chalk. Classic: near-black with a soft crimson glow in the
/// top corner and a faint blue one low down, like the gym's lighting. Static on purpose: a
/// front-desk screen is on all day.
class GlowBackground extends StatelessWidget {
  final Widget child;

  const GlowBackground({super.key, required this.child});

  Widget _glow(Color color, double alpha, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (Skin.classic) {
      return DecoratedBox(
        decoration: BoxDecoration(color: AppColors.background),
        child: Stack(children: [
          Positioned(top: -180, right: -140, child: _glow(AppColors.primary, 0.22, 460)),
          Positioned(bottom: -220, left: -180, child: _glow(AppColors.seriesCompare, 0.08, 440)),
          // Transparent Material so ink ripples paint above the background.
          Positioned.fill(child: Material(type: MaterialType.transparency, child: child)),
        ]),
      );
    }
    return ColoredBox(
      color: AppColors.background,
      // Transparent Material so ink ripples paint above the background.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Shrinks slightly while pressed and gives a light haptic tap. Wrap anything tappable.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.pressedScale = 0.97, this.haptic = true});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: Motion.fast,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// The app's card. Plate & Chalk: a sheet of the register, white with a hairline edge and no shadow;
/// [gradient] (the iron panel) makes the one inverted summary on a screen and [glow] is ignored.
/// Classic: a dark surface whose hairline border is a touch brighter on top, like light catching an
/// edge; [gradient] makes a red hero card and [glow] adds a crimson halo.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final Color? color;
  final bool glow;
  final double? radius;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.gradient,
    this.color,
    this.glow = false,
    this.radius,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Skin.classic) return _classic();
    final inverted = gradient != null && color == null;
    final card = Container(
      decoration: BoxDecoration(
        color: inverted ? null : (color ?? AppColors.surface),
        gradient: inverted ? gradient : null,
        borderRadius: BorderRadius.circular(radius ?? 14),
        border: inverted ? null : Border.all(color: borderColor ?? AppColors.border),
      ),
      // A transparent Material so list tiles inside the card show their tap ripple.
      child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, pressedScale: 0.985, child: card);
  }

  Widget _classic() {
    final shape = BorderRadius.circular(radius ?? 22);
    final card = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? (gradient ?? AppColors.surfaceGradient) : null,
        borderRadius: shape,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: glow ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -12, offset: const Offset(0, 18))] : null,
      ),
      foregroundDecoration: gradient == null
          ? BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.white.withValues(alpha: 0.035), Colors.white.withValues(alpha: 0)],
              ),
            )
          : null,
      child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// Plate & Chalk: an icon on its own, in ink, so a page is not a box of coloured squares; only an
/// alert (red) keeps its colour. Classic: a rounded square with the icon on a tinted background.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double radius;

  const IconBadge(this.icon, {super.key, this.color, this.size = 40, this.radius = 13});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    if (Skin.classic) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: c.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, color: c, size: size * 0.5),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      // Only an alert keeps its colour; every other icon is ink.
      child: Center(child: Icon(icon, color: c == AppColors.danger ? c : AppColors.text, size: size * 0.56)),
    );
  }
}
