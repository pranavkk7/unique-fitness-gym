import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';

/// Page background: plain chalk. Kept as a widget so pages keep one place for it.
class GlowBackground extends StatelessWidget {
  final Widget child;

  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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

/// A sheet of the register: white, a hairline edge, no shadow. [gradient] (the iron panel) makes the
/// one inverted summary on a screen. [glow] is ignored: nothing in the app glows.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? gradient;
  final Color? color;
  final bool glow;
  final double radius;
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
    this.radius = 14,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final inverted = gradient != null && color == null;
    final card = Container(
      decoration: BoxDecoration(
        color: inverted ? null : (color ?? AppColors.surface),
        gradient: inverted ? gradient : null,
        borderRadius: BorderRadius.circular(radius),
        border: inverted ? null : Border.all(color: borderColor ?? AppColors.border),
      ),
      // A transparent Material so list tiles inside the card show their tap ripple.
      child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, pressedScale: 0.985, child: card);
  }
}

/// An icon on its own, in ink, so a page is not a box of coloured squares. Only an alert (red) keeps
/// its colour; state is shown with plate rings and words instead.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  const IconBadge(this.icon, {super.key, this.color = AppColors.primary, this.size = 40, this.radius = 13});

  // Only an alert keeps its colour; every other icon is ink.
  static const _states = [AppColors.danger];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: Icon(icon, color: _states.contains(color) ? color : AppColors.text, size: size * 0.56)),
    );
  }
}
