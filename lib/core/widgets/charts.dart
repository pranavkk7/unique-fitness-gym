import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/motion.dart';
import '../utils/format.dart';

/// One bar: short axis label, full label for the bubble, the value, and an optional comparison value.
class BarDatum {
  final String label;
  final String fullLabel;
  final double value;
  final double? compare;

  const BarDatum(this.label, this.fullLabel, this.value, {this.compare});
}

/// Monthly income bars, drawn by hand so they can move the way a premium dashboard should:
/// bars rise one after another, a value bubble glides to the bar you touch, and dragging across
/// the chart scrubs month by month with a haptic tick. Comparison bars (same month last year)
/// sit beside each bar when [showCompare] is on, and a dashed line marks the monthly target.
class RevenueBars extends StatefulWidget {
  final List<BarDatum> data;
  final int selected;
  final ValueChanged<int>? onSelect;
  final bool showCompare;
  final double? target;
  final double height;
  final String semanticLabel;

  const RevenueBars({
    super.key,
    required this.data,
    required this.selected,
    this.onSelect,
    this.showCompare = false,
    this.target,
    this.height = 230,
    required this.semanticLabel,
  });

  @override
  State<RevenueBars> createState() => _RevenueBarsState();
}

class _RevenueBarsState extends State<RevenueBars> with TickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(vsync: this, duration: Motion.chart);
  late final AnimationController _slide = AnimationController(vsync: this, duration: Motion.medium);
  List<double> _from = const [], _to = const [], _fromCmp = const [], _toCmp = const [];
  double _fromMax = 0, _toMax = 0;
  double _fromSel = 0;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true; // first build: the reduced-motion setting can only be read from here on
    _setTargets(initial: true);
    _fromSel = widget.selected.toDouble();
    _slide.value = 1;
  }

  @override
  void didUpdateWidget(RevenueBars old) {
    super.didUpdateWidget(old);
    final changed = old.data.length != widget.data.length ||
        old.showCompare != widget.showCompare ||
        old.target != widget.target ||
        [for (var i = 0; i < widget.data.length; i++) old.data[i].value != widget.data[i].value || old.data[i].compare != widget.data[i].compare].any((x) => x);
    if (changed) _setTargets();
    if (old.selected != widget.selected) {
      _fromSel = _currentSel();
      _slide.forward(from: 0);
    }
  }

  double _currentSel() => ui.lerpDouble(_fromSel, widget.selected.toDouble(), Motion.settle.transform(_slide.value))!;

  void _setTargets({bool initial = false}) {
    final n = widget.data.length;
    if (initial || _from.length != n) {
      _from = List.filled(n, 0);
      _fromCmp = List.filled(n, 0);
      _fromMax = 0;
    } else {
      _from = [for (var i = 0; i < n; i++) _valueAt(_from, _to, i)];
      _fromCmp = [for (var i = 0; i < n; i++) _valueAt(_fromCmp, _toCmp, i)];
      _fromMax = _maxNow();
    }
    _to = [for (final d in widget.data) d.value];
    _toCmp = [for (final d in widget.data) widget.showCompare ? (d.compare ?? 0) : 0];
    final peak = [..._to, ..._toCmp, widget.target ?? 0].fold<double>(0, math.max);
    final step = niceStep(peak <= 0 ? 1000 : peak, 4);
    _toMax = math.max(step, (peak / step).ceil() * step);
    if (_fromMax == 0) _fromMax = _toMax;
    if (Motion.reduced(context)) {
      _grow.value = 1;
    } else {
      _grow.forward(from: 0);
    }
  }

  double _progress(int i) {
    final n = math.max(1, widget.data.length);
    const spread = 0.35; // share of the animation spent starting bars one after another
    final local = ((_grow.value - spread * i / n) / (1 - spread)).clamp(0.0, 1.0);
    return Motion.settle.transform(local);
  }

  double _valueAt(List<double> from, List<double> to, int i) {
    if (i >= to.length) return 0;
    final f = i < from.length ? from[i] : 0.0;
    return ui.lerpDouble(f, to[i], _progress(i))!;
  }

  double _maxNow() => ui.lerpDouble(_fromMax, _toMax, Motion.settle.transform(_grow.value))!;

  void _pick(Offset local, double width) {
    final n = widget.data.length;
    if (n == 0 || widget.onSelect == null) return;
    final plotW = width - _RevenuePainter.left;
    final i = ((local.dx - _RevenuePainter.left) / (plotW / n)).floor().clamp(0, n - 1);
    if (i != widget.selected) {
      HapticFeedback.selectionClick();
      widget.onSelect!(i);
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, box) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _pick(d.localPosition, box.maxWidth),
          onHorizontalDragUpdate: (d) => _pick(d.localPosition, box.maxWidth),
          child: AnimatedBuilder(
            animation: Listenable.merge([_grow, _slide]),
            builder: (context, _) => CustomPaint(
              size: Size(box.maxWidth, widget.height),
              painter: _RevenuePainter(
                data: widget.data,
                values: [for (var i = 0; i < widget.data.length; i++) _valueAt(_from, _to, i)],
                compare: [for (var i = 0; i < widget.data.length; i++) _valueAt(_fromCmp, _toCmp, i)],
                showCompare: widget.showCompare,
                maxY: _maxNow(),
                selected: widget.selected,
                selectedPos: _currentSel(),
                target: widget.target,
                reveal: _grow.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevenuePainter extends CustomPainter {
  static const left = 44.0;
  static const bottom = 26.0;
  static const top = 38.0;

  final List<BarDatum> data;
  final List<double> values;
  final List<double> compare;
  final bool showCompare;
  final double maxY;
  final int selected;
  final double selectedPos;
  final double? target;
  final double reveal;

  _RevenuePainter({
    required this.data,
    required this.values,
    required this.compare,
    required this.showCompare,
    required this.maxY,
    required this.selected,
    required this.selectedPos,
    required this.target,
    required this.reveal,
  });

  TextPainter _text(String s, TextStyle style) => TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.length;
    if (n == 0 || maxY <= 0) return;
    final plotW = size.width - left;
    final plotH = size.height - bottom - top;
    final slot = plotW / n;
    double y(double v) => top + plotH - (v / maxY).clamp(0.0, 1.05) * plotH;

    // Recessive grid and axis labels.
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final step = niceStep(maxY, 4);
    const axisStyle = TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
    for (var v = 0.0; v <= maxY + 0.5; v += step) {
      final gy = y(v);
      canvas.drawLine(Offset(left, gy), Offset(size.width, gy), grid);
      final t = _text(v == 0 ? '0' : formatMoneyCompact(v), axisStyle);
      t.paint(canvas, Offset(left - 8 - t.width, gy - t.height / 2));
    }

    // Bars: the selected month in full colour, the rest quieter so the eye lands on it first.
    final barW = showCompare ? math.min(13.0, slot * 0.3) : math.min(26.0, slot * 0.56);
    const gap = 2.0;
    const radius = Radius.circular(4);
    for (var i = 0; i < n; i++) {
      final cx = left + slot * (i + 0.5);
      final isSel = i == selected;
      final mainX = showCompare ? cx + gap / 2 : cx - barW / 2;
      if (showCompare) {
        final rect = Rect.fromLTRB(cx - gap / 2 - barW, y(compare[i]), cx - gap / 2, y(0));
        if (rect.height > 0.5) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
            Paint()..color = AppColors.seriesCompare.withValues(alpha: isSel ? 0.95 : 0.38),
          );
        }
      }
      final rect = Rect.fromLTRB(mainX, y(values[i]), mainX + barW, y(0));
      if (rect.height > 0.5) {
        final paint = Paint();
        if (isSel) {
          paint.shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primaryBright, Color(0xFFB0101A)]).createShader(rect);
        } else {
          paint.color = AppColors.primary.withValues(alpha: 0.36);
        }
        canvas.drawRRect(RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius), paint);
      }

      final label = _text(
        data[i].label.toUpperCase(),
        TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 10.5, letterSpacing: 0.6, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? AppColors.text : AppColors.muted),
      );
      label.paint(canvas, Offset(cx - label.width / 2, size.height - bottom + 8));
    }

    // Monthly target as a dashed line.
    if (target != null && target! > 0 && target! <= maxY * 1.05) {
      final ty = y(target!);
      final dash = Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * reveal)
        ..strokeWidth = 1.2;
      for (var x = left; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ty), Offset(math.min(x + 4, size.width), ty), dash);
      }
      final t = _text('TARGET', const TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.textSecondary));
      final box = Rect.fromLTWH(size.width - t.width - 10, ty - t.height - 6, t.width + 8, t.height + 3);
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(4)), Paint()..color = AppColors.background.withValues(alpha: 0.85 * reveal));
      t.paint(canvas, Offset(box.left + 4, box.top + 1.5));
    }

    // Value bubble that glides between bars.
    if (selected >= 0 && selected < n) {
      final bx = left + slot * (selectedPos + 0.5);
      final value = values[selected];
      final cmp = showCompare ? compare[selected] : null;
      final text = _text(formatMoney(value), const TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, fontFeatures: [FontFeature.tabularFigures()]));
      final w = text.width + 18;
      final barTop = math.min(y(value), cmp == null ? double.infinity : y(cmp));
      final bubbleY = math.max(2.0, barTop - text.height - 16);
      final r = Rect.fromCenter(center: Offset(bx.clamp(left + w / 2, size.width - w / 2), bubbleY + (text.height + 8) / 2), width: w, height: text.height + 8);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: 0.35));
      canvas.drawRRect(rr, Paint()..color = AppColors.surfaceHigher);
      canvas.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..color = AppColors.primary.withValues(alpha: 0.6));
      final arrow = Path()
        ..moveTo(bx - 5, r.bottom)
        ..lineTo(bx, r.bottom + 5)
        ..lineTo(bx + 5, r.bottom)
        ..close();
      canvas.drawPath(arrow, Paint()..color = AppColors.surfaceHigher);
      text.paint(canvas, Offset(r.left + 9, r.top + 4));
    }
  }

  @override
  bool shouldRepaint(_RevenuePainter old) => true;
}

/// A ring that fills to [value] (0 to 1) with a crimson sweep. Used for the monthly target and
/// for how much of a membership is used.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  const ProgressRing({super.key, required this.value, this.size = 120, this.stroke = 11, this.color, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1300),
        curve: Motion.settle,
        builder: (context, v, child) => CustomPaint(painter: _RingPainter(v, stroke, color), child: child),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color? color;

  _RingPainter(this.value, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(arc, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.08));
    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (color != null) {
      paint.color = color!;
    } else {
      paint.shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: const [Color(0xFF8E0008), AppColors.primary, AppColors.primaryBright, Color(0xFFFF8A5B)],
        stops: const [0, 0.4, 0.8, 1],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    }
    canvas.drawArc(arc, -math.pi / 2, sweep, false, paint);
    // A bright dot at the head of the arc.
    final head = Offset(arc.center.dx + arc.width / 2 * math.cos(-math.pi / 2 + sweep), arc.center.dy + arc.height / 2 * math.sin(-math.pi / 2 + sweep));
    canvas.drawCircle(head, stroke * 0.32, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Parts of a whole as one bar with 2px gaps (payment methods). Segments grow in from the left.
class SplitBar extends StatelessWidget {
  final List<(double value, Color color)> parts;
  final double height;

  const SplitBar({super.key, required this.parts, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (s, p) => s + p.$1);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.reduced(context) ? Duration.zero : Motion.chart,
      curve: Motion.settle,
      builder: (context, t, _) => LayoutBuilder(
        builder: (context, box) {
          final visible = parts.where((p) => p.$1 > 0).toList();
          if (total <= 0 || visible.isEmpty) {
            return Container(height: height, decoration: BoxDecoration(color: AppColors.surfaceHigher, borderRadius: BorderRadius.circular(height)));
          }
          final usable = box.maxWidth - 2 * (visible.length - 1);
          return ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Container(width: usable * visible[i].$1 / total * t, color: visible[i].$2),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A small smoothed line with a soft fill, drawn left to right when it appears.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const Sparkline({super.key, required this.values, this.color = Colors.white, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1400),
      curve: Motion.settle,
      builder: (context, t, _) => CustomPaint(size: Size(double.infinity, height), painter: _SparkPainter(values, color, t)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double t;

  _SparkPainter(this.values, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final peak = values.fold<double>(0, math.max);
    final maxV = peak <= 0 ? 1 : peak * 1.15;
    final pts = [for (var i = 0; i < values.length; i++) Offset(size.width * i / (values.length - 1), size.height - 4 - (values[i] / maxV) * (size.height - 8))];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)]).createShader(Offset.zero & size),
    );
    canvas.drawPath(line, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color);
    canvas.restore();
    if (t >= 1) {
      canvas.drawCircle(pts.last, 4.5, Paint()..color = color);
      canvas.drawCircle(pts.last, 9, Paint()..color = color.withValues(alpha: 0.25));
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t || old.values != values;
}

/// Busy hours: average check-ins per weekday (rows) and hour (columns), one crimson hue from dark
/// to bright. Tap a cell to read its value.
class BusyHeatmap extends StatefulWidget {
  final List<List<double>> grid; // 7 rows, Monday first
  final int firstHour;

  const BusyHeatmap({super.key, required this.grid, required this.firstHour});

  @override
  State<BusyHeatmap> createState() => _BusyHeatmapState();
}

class _BusyHeatmapState extends State<BusyHeatmap> {
  (int, int)? _cell;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _hour(int h) => h == 12 ? '12p' : (h < 12 ? '${h}a' : '${h - 12}p');

  @override
  Widget build(BuildContext context) {
    final cols = widget.grid.isEmpty ? 0 : widget.grid.first.length;
    final peak = widget.grid.expand((r) => r).fold<double>(0, math.max);
    // The busiest slot, called out under the grid until a cell is tapped.
    var best = (0, 0);
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < cols; c++) {
        if (widget.grid[r][c] > widget.grid[best.$1][best.$2]) best = (r, c);
      }
    }
    final shown = _cell ?? best;
    final shownValue = cols == 0 ? 0.0 : widget.grid[shown.$1][shown.$2];
    final h = widget.firstHour + shown.$2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, box) {
          const labelW = 30.0;
          final cell = (box.maxWidth - labelW) / math.max(1, cols);
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1100),
            curve: Curves.easeOut,
            builder: (context, t, _) => GestureDetector(
              onTapDown: (d) {
                final c = ((d.localPosition.dx - labelW) / cell).floor();
                final r = (d.localPosition.dy / (cell * 0.9)).floor();
                if (c >= 0 && c < cols && r >= 0 && r < 7) {
                  HapticFeedback.selectionClick();
                  setState(() => _cell = (r, c));
                }
              },
              child: CustomPaint(
                size: Size(box.maxWidth, cell * 0.9 * 7 + 18),
                painter: _HeatPainter(widget.grid, peak, labelW, cell, t, _cell, _days, [for (var c = 0; c < cols; c++) (widget.firstHour + c) % 3 == 0 ? _hour(widget.firstHour + c) : '']),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        Text(
          '${_cell == null ? 'Busiest: ' : ''}${_days[shown.$1]} ${_hour(h)} to ${_hour(h + 1)} · about ${shownValue.toStringAsFixed(shownValue < 10 ? 1 : 0)} check-ins',
          style: AppText.small,
        ),
      ],
    );
  }
}

class _HeatPainter extends CustomPainter {
  final List<List<double>> grid;
  final double peak;
  final double labelW;
  final double cell;
  final double t;
  final (int, int)? selected;
  final List<String> days;
  final List<String> hours;

  _HeatPainter(this.grid, this.peak, this.labelW, this.cell, this.t, this.selected, this.days, this.hours);

  @override
  void paint(Canvas canvas, Size size) {
    final cols = hours.length;
    final rowH = cell * 0.9;
    const labelStyle = TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted);
    for (var r = 0; r < 7; r++) {
      final tp = TextPainter(text: TextSpan(text: days[r].substring(0, 1) + days[r].substring(1, 2), style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, r * rowH + (rowH - tp.height) / 2));
      for (var c = 0; c < cols; c++) {
        // Columns appear left to right as the grid fades in.
        final appear = ((t * 1.4) - c / cols * 0.4).clamp(0.0, 1.0);
        final v = peak <= 0 ? 0.0 : math.sqrt(grid[r][c] / peak); // square root keeps quiet hours visible
        final color = Color.lerp(AppColors.surfaceHigh, AppColors.primaryBright, v)!.withValues(alpha: appear);
        final rect = Rect.fromLTWH(labelW + c * cell + 1.5, r * rowH + 1.5, cell - 3, rowH - 3);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = color);
        if (selected == (r, c)) {
          canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(5)), Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white);
        }
      }
    }
    for (var c = 0; c < cols; c++) {
      if (hours[c].isEmpty) continue;
      final tp = TextPainter(text: TextSpan(text: hours[c], style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(labelW + c * cell + (cell - tp.width) / 2, 7 * rowH + 4));
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) => old.t != t || old.selected != selected || old.grid != grid;
}

/// Ranked horizontal bars with every value printed (plans, expense categories, lead sources).
class RankedBars extends StatelessWidget {
  final List<(String label, double value, String display)> items;
  final Color color;

  const RankedBars({super.key, required this.items, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    final peak = items.fold<double>(0, (m, e) => math.max(m, e.$2));
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
            child: Semantics(
              label: '${items[i].$1}: ${items[i].$3}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(items[i].$1, style: AppText.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      Text(items[i].$3, style: AppText.number),
                    ],
                  ),
                  const SizedBox(height: 7),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: peak == 0 ? 0.0 : items[i].$2 / peak),
                    duration: Motion.reduced(context) ? Duration.zero : Motion.chart + Motion.stagger * i,
                    curve: Motion.settle,
                    builder: (context, f, _) => Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: AppColors.surfaceHigher, borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: f.clamp(0.012, 1.0),
                          child: Container(height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Visits per week as small columns (the attendance strip on a profile).
class WeekColumns extends StatelessWidget {
  final List<int> counts;
  final double height;

  const WeekColumns({super.key, required this.counts, this.height = 54});

  @override
  Widget build(BuildContext context) {
    final peak = math.max(1, counts.fold<int>(0, math.max));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < counts.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: counts[i] / peak),
                  duration: Motion.reduced(context) ? Duration.zero : Motion.chart + Motion.stagger * i,
                  curve: Motion.settle,
                  builder: (context, f, _) => Container(
                    height: math.max(3, height * f),
                    decoration: BoxDecoration(
                      color: i == counts.length - 1 ? AppColors.primary : AppColors.primary.withValues(alpha: counts[i] == 0 ? 0.15 : 0.45),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Today's door entries hour by hour (crimson area) against a usual day of the same weekday
/// (blue dashed line), with a marker at the current time. The area draws itself up to "now".
class RushHoursChart extends StatelessWidget {
  final List<double> today;
  final List<double> usual;
  final int firstHour;
  final double nowHour; // e.g. 18.33 for 6:20 PM
  final double height;

  const RushHoursChart({super.key, required this.today, required this.usual, required this.firstHour, required this.nowHour, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Check-ins by hour today compared with a usual day',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1600),
        curve: Motion.settle,
        builder: (context, t, _) => CustomPaint(size: Size(double.infinity, height), painter: _RushPainter(today, usual, firstHour, nowHour, t)),
      ),
    );
  }
}

class _RushPainter extends CustomPainter {
  final List<double> today;
  final List<double> usual;
  final int firstHour;
  final double nowHour;
  final double t;

  _RushPainter(this.today, this.usual, this.firstHour, this.nowHour, this.t);

  static const _label = TextStyle(fontFamily: AppText.bodyFont, fontFamilyFallback: AppText.fallback, fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted);

  String _hourText(int h) => h == 12 ? '12p' : (h < 12 ? '${h}a' : '${h - 12}p');

  @override
  void paint(Canvas canvas, Size size) {
    final n = today.length;
    if (n < 2) return;
    const bottom = 20.0, top = 18.0;
    final plotH = size.height - bottom - top;
    final peak = [...today, ...usual].fold<double>(1, math.max) * 1.15;
    double x(double i) => size.width * i / (n - 1);
    double y(double v) => top + plotH - (v / peak) * plotH;

    // Baseline and hour labels.
    canvas.drawLine(Offset(0, top + plotH), Offset(size.width, top + plotH), Paint()..color = AppColors.border);
    for (var i = 0; i < n; i++) {
      final h = firstHour + i;
      if (h % 3 != 0) continue;
      final tp = TextPainter(text: TextSpan(text: _hourText(h), style: _label), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((x(i.toDouble()) - tp.width / 2).clamp(0, size.width - tp.width), size.height - bottom + 6));
    }

    Path smooth(List<double> v, int upto) {
      final p = Path()..moveTo(x(0), y(v[0]));
      for (var i = 1; i <= upto && i < v.length; i++) {
        final mx = (x(i - 1.0) + x(i.toDouble())) / 2;
        p.cubicTo(mx, y(v[i - 1]), mx, y(v[i]), x(i.toDouble()), y(v[i]));
      }
      return p;
    }

    // Usual day: dashed blue line across the whole day.
    final usualPath = smooth(usual, n - 1);
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = AppColors.seriesCompare.withValues(alpha: 0.9);
    for (final metric in usualPath.computeMetrics()) {
      for (var d = 0.0; d < metric.length * t; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length * t)), dash);
      }
    }

    // Today: filled crimson area up to now, drawn left to right.
    final nowIndex = (nowHour - firstHour).clamp(0, n - 1.0).toDouble();
    final upto = nowIndex.ceil();
    final todayPath = smooth(today, upto);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, x(nowIndex) * t + 1, size.height));
    final area = Path.from(todayPath)
      ..lineTo(x(upto.toDouble()), top + plotH)
      ..lineTo(0, top + plotH)
      ..close();
    canvas.drawPath(
      area,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withValues(alpha: 0.45), AppColors.primary.withValues(alpha: 0)]).createShader(Offset.zero & size),
    );
    canvas.drawPath(todayPath, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..color = AppColors.primaryBright);
    canvas.restore();

    // "Now" marker.
    if (t > 0.6) {
      final nx = x(nowIndex);
      final a = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
      canvas.drawLine(Offset(nx, top - 4), Offset(nx, top + plotH), Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * a)
        ..strokeWidth = 1);
      final tp = TextPainter(text: TextSpan(text: 'NOW', style: _label.copyWith(color: Colors.white.withValues(alpha: a), fontWeight: FontWeight.w800, letterSpacing: 1)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset((nx - tp.width / 2).clamp(0, size.width - tp.width), 0));
    }
  }

  @override
  bool shouldRepaint(_RushPainter old) => old.t != t || old.nowHour != nowHour || old.today != today;
}

/// Tiny column chart for a stat tile; the first column is the one that matters now.
class MiniColumns extends StatelessWidget {
  final List<double> values;
  final Color color;

  const MiniColumns({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final peak = values.fold<double>(0, math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: peak == 0 ? 0 : values[i] / peak),
                duration: Motion.reduced(context) ? Duration.zero : Motion.chart + Motion.stagger * i,
                curve: Motion.settle,
                builder: (context, f, _) => FractionallySizedBox(
                  heightFactor: f.clamp(0.08, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(decoration: BoxDecoration(color: color.withValues(alpha: i == 0 ? 1 : 0.55), borderRadius: const BorderRadius.vertical(top: Radius.circular(2)))),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
