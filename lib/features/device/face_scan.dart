import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';

/// The face-scan illustration on the register screen: a face in corner brackets with a laser line
/// sweeping over it while the terminal waits, turning green when the face is enrolled.
class FaceScan extends StatefulWidget {
  final bool scanning;
  final bool done;
  final double size;

  const FaceScan({super.key, required this.scanning, this.done = false, this.size = 190});

  @override
  State<FaceScan> createState() => _FaceScanState();
}

class _FaceScanState extends State<FaceScan> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(FaceScan old) {
    super.didUpdateWidget(old);
    _update();
  }

  void _update() {
    final run = widget.scanning && !widget.done && !Motion.reduced(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.done ? AppColors.success : AppColors.primaryBright;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ScanPainter(_c.value, color, widget.scanning && !widget.done)),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool scanning;

  _ScanPainter(this.t, this.color, this.scanning);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final inset = r.deflate(size.width * 0.08);
    // Soft pulsing glow behind the face.
    final pulse = scanning ? (0.5 + 0.5 * math.sin(t * math.pi * 2)) : 1.0;
    canvas.drawCircle(r.center, size.width * (0.34 + 0.04 * pulse), Paint()..color = color.withValues(alpha: 0.10 + 0.08 * pulse));

    // Corner brackets.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round
      ..color = color;
    final l = size.width * 0.18;
    for (final (corner, dx, dy) in [(inset.topLeft, 1.0, 1.0), (inset.topRight, -1.0, 1.0), (inset.bottomLeft, 1.0, -1.0), (inset.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(corner, corner + Offset(l * dx, 0), bracket);
      canvas.drawLine(corner, corner + Offset(0, l * dy), bracket);
    }

    // A simple face: head outline, eyes, smile.
    final face = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.022
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.85);
    final c = r.center;
    final w = size.width;
    canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.42, height: w * 0.52), face);
    canvas.drawCircle(c + Offset(-w * 0.075, -w * 0.05), w * 0.018, Paint()..color = Colors.white);
    canvas.drawCircle(c + Offset(w * 0.075, -w * 0.05), w * 0.018, Paint()..color = Colors.white);
    canvas.drawArc(Rect.fromCenter(center: c + Offset(0, w * 0.06), width: w * 0.16, height: w * 0.1), 0.2, math.pi - 0.4, false, face);

    // Mesh dots that light up as the line passes, like a face being mapped.
    final lineY = inset.top + inset.height * (scanning ? t : 1);
    final rng = math.Random(3);
    for (var i = 0; i < 26; i++) {
      final p = c + Offset((rng.nextDouble() - 0.5) * w * 0.38, (rng.nextDouble() - 0.5) * w * 0.48);
      final lit = !scanning || p.dy < lineY;
      canvas.drawCircle(p, w * 0.008, Paint()..color = color.withValues(alpha: lit ? 0.9 : 0.15));
    }

    // The laser line.
    if (scanning) {
      final band = Rect.fromLTWH(inset.left, lineY - w * 0.08, inset.width, w * 0.08);
      canvas.drawRect(band, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.35)]).createShader(band));
      canvas.drawLine(Offset(inset.left + 6, lineY), Offset(inset.right - 6, lineY), Paint()
        ..color = color
        ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t || old.color != color || old.scanning != scanning;
}
