import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';
import 'brand.dart';

/// The opening moment: one choreographed sequence on a single timeline, so every part moves in
/// step. The logo comes into focus as it settles (blur, scale and fade together), a fine plate rim
/// draws around it, and the name rises in underneath. Classic swaps the rim for a red glow and a
/// red line that sweeps out under the logo.
///
/// The logo image is decoded before the timeline starts, so it never pops in halfway. [onDone]
/// fires when the sequence has finished (at once when the system asks for reduced motion).
class SplashLogo extends StatefulWidget {
  final VoidCallback? onDone;

  const SplashLogo({super.key, this.onDone});

  @override
  State<SplashLogo> createState() => _SplashLogoState();
}

class _SplashLogoState extends State<SplashLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: Skin.classic ? 1700 : 1500));
  bool _started = false;

  // An expo-style ease: quick to start, a long soft landing. It reads as weight settling.
  static const _settle = Cubic(0.16, 1, 0.3, 1);

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    final asset = Skin.classic ? BrandLogo.darkAsset : BrandLogo.originalAsset;
    precacheImage(AssetImage(asset), context).whenComplete(() {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// The timeline value for one part of the sequence, eased.
  double _part(double begin, double end, [Curve curve = _settle]) => curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Skin.classic ? _classic() : _chalk(),
      ),
    );
  }

  /// The logo coming into focus: blur clears, scale settles and opacity rises together.
  Widget _focus({required double t, required double height, required double from}) {
    Widget logo = BrandLogo(height: height);
    final blur = (1 - t) * 14;
    if (blur > 0.05) logo = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: logo);
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: Transform.scale(scale: from + (1 - from) * t, child: logo)),
    );
  }

  /// A line of text that rises a little and closes its letter spacing as it appears.
  Widget _rise(String text, TextStyle style, double t, {double spacingFrom = 0}) {
    final spacing = (style.letterSpacing ?? 0) + spacingFrom * (1 - t);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: Text(text, style: style.copyWith(letterSpacing: spacing))),
    );
  }

  Widget _chalk() {
    const logoH = 128.0;
    final logo = _part(0.0, 0.62);
    final rim = _part(0.16, 0.80, Curves.easeInOutCubic);
    final name = _part(0.46, 0.94);
    final place = _part(0.60, 1.0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox.square(
        dimension: 196,
        child: Stack(alignment: Alignment.center, children: [
          // The plate rim draws once around the badge, like the edge of a weight plate.
          Positioned.fill(child: CustomPaint(painter: _RimPainter(progress: rim, color: AppColors.text))),
          _focus(t: logo, height: logoH, from: 0.88),
        ]),
      ),
      const SizedBox(height: 14),
      _rise('Unique Fitness', AppText.display.copyWith(fontSize: 24), name, spacingFrom: 3),
      const SizedBox(height: 4),
      _rise('Pinarayi', AppText.bodyMuted, place, spacingFrom: 1.5),
    ]);
  }

  Widget _classic() {
    final logo = _part(0.0, 0.58);
    // The glow swells past its resting brightness, then eases back, like stage lights coming up.
    final glow = _part(0.10, 0.55) * (1 - 0.35 * _part(0.55, 1.0, Curves.easeInOut));
    final line = _part(0.34, 0.86, Curves.easeInOutCubic);
    final name = _part(0.42, 0.88);
    final tag = _part(0.58, 1.0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.5 * glow), blurRadius: 90, spreadRadius: 8)]),
        child: _focus(t: logo, height: 150, from: 0.82),
      ),
      const SizedBox(height: 22),
      _rise('UNIQUE FITNESS', AppText.headline.copyWith(fontSize: 30, letterSpacing: 1.2), name, spacingFrom: 4),
      const SizedBox(height: 12),
      // A red line sweeps out from the centre, like a progress bar filling.
      SizedBox(
        width: 160,
        height: 3,
        child: Center(
          child: Container(
            width: 160 * line,
            height: 3,
            decoration: BoxDecoration(gradient: AppColors.redGradient, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _rise('PREMIUM LUXURY FITNESS CENTRE', AppText.label.copyWith(letterSpacing: 3.5, color: AppColors.textSecondary), tag, spacingFrom: 3),
    ]);
  }
}

/// A fine ring drawn clockwise from the top, with a soft fade along its tail so the moving end
/// leads the eye.
class _RimPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RimPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rect = (Offset.zero & size).deflate(2);
    final sweep = math.pi * 2 * progress;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.28)],
        stops: [0, progress.clamp(0.001, 1.0)],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.progress != progress || old.color != color;
}
