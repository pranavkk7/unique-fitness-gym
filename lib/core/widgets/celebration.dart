import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';

enum BurstKind { success, warning, error }

/// The check-in and admission moment: a disc pops in, the tick (or ! or ×) draws itself, and a
/// ring of sparks flies out. One controller, painted on a canvas, so it stays smooth on a cheap
/// front-desk phone.
class SuccessBurst extends StatefulWidget {
  final BurstKind kind;
  final double size;

  /// Fills the disc first, so the burst can sit on top of a photo as a badge.
  final Color? backing;

  const SuccessBurst({super.key, this.kind = BurstKind.success, this.size = 132, this.backing});

  @override
  State<SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<SuccessBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      Motion.reduced(context) ? _c.value = 1 : _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.kind) {
      BurstKind.success => AppColors.success,
      BurstKind.warning => AppColors.warning,
      BurstKind.error => AppColors.danger,
    };
    return Semantics(
      label: switch (widget.kind) { BurstKind.success => 'Done', BurstKind.warning => 'Warning', BurstKind.error => 'Not allowed' },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _BurstPainter(_c.value, color, widget.kind, widget.backing)),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double t;
  final Color color;
  final BurstKind kind;
  final Color? backing;

  _BurstPainter(this.t, this.color, this.kind, this.backing);

  double _seg(double a, double b, [Curve curve = Curves.easeOutCubic]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.3;

    // Sparks flying outwards and fading.
    final spark = _seg(0.15, 0.85);
    if (spark > 0 && spark < 1) {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6 + 0.2;
        final d1 = r * (1.05 + 0.55 * spark);
        final d2 = r * (1.15 + 0.85 * spark);
        final p = Paint()
          ..color = (i.isEven ? color : AppColors.primaryBright).withValues(alpha: 1 - spark)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * d1, c + Offset(math.cos(a), math.sin(a)) * d2, p);
      }
    }

    // Expanding halo.
    final halo = _seg(0.0, 0.7);
    canvas.drawCircle(c, r * (1 + 0.6 * halo), Paint()..color = color.withValues(alpha: 0.22 * (1 - halo)));

    // Disc pops in with a slight overshoot.
    final pop = _seg(0.0, 0.45, Curves.easeOutBack);
    if (backing != null) canvas.drawCircle(c, r * pop, Paint()..color = backing!);
    canvas.drawCircle(c, r * pop, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawCircle(c, r * pop, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color);

    // The mark draws itself.
    final draw = _seg(0.3, 0.75);
    if (draw <= 0) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path();
    switch (kind) {
      case BurstKind.success:
        path
          ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
          ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
          ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3);
      case BurstKind.warning:
        path
          ..moveTo(c.dx, c.dy - r * 0.45)
          ..lineTo(c.dx, c.dy + r * 0.1)
          ..moveTo(c.dx, c.dy + r * 0.38)
          ..lineTo(c.dx, c.dy + r * 0.4);
      case BurstKind.error:
        path
          ..moveTo(c.dx - r * 0.34, c.dy - r * 0.34)
          ..lineTo(c.dx + r * 0.34, c.dy + r * 0.34)
          ..moveTo(c.dx + r * 0.34, c.dy - r * 0.34)
          ..lineTo(c.dx - r * 0.34, c.dy + r * 0.34);
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * draw), stroke);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Confetti in the gym's colours, falling once over [child] (a new admission).
class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _show = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _show = false;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _show = false);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_show)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(animation: _c, builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value))),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  static final _pieces = List.generate(70, (i) {
    final r = math.Random(i * 7919);
    return (r.nextDouble(), r.nextDouble() * 0.35, 0.6 + r.nextDouble() * 0.8, r.nextDouble() * math.pi * 2, r.nextInt(4), (r.nextDouble() - 0.5) * 0.25);
  });
  static const _colors = [AppColors.primary, AppColors.primaryBright, Colors.white, AppColors.ember];

  _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, delay, speed, spin, color, drift) in _pieces) {
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * speed * size.height * 1.1;
      final px = (x + drift * local) * size.width + math.sin(local * 10 + spin) * 12;
      final paint = Paint()..color = _colors[color].withValues(alpha: (1 - local).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(px, y);
      canvas.rotate(spin + local * 8);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
