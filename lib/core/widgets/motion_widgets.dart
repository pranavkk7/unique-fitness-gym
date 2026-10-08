import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// A headline that rises letter by letter out of its own line, like a poster being printed.
/// Plays once when first shown.
class RevealText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration delay;
  final TextAlign align;

  const RevealText(this.text, {super.key, required this.style, this.delay = Duration.zero, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text(text, style: style, textAlign: align);
    final perChar = text.length > 24 ? 14 : 24;
    final total = Duration(milliseconds: 520 + perChar * text.length) + delay;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: total,
        builder: (context, t, _) {
          final ms = t * total.inMilliseconds - delay.inMilliseconds;
          return Text.rich(
            TextSpan(children: [
              for (var i = 0; i < text.length; i++) _char(text[i], ((ms - i * perChar) / 520).clamp(0.0, 1.0)),
            ]),
            textAlign: align,
          );
        },
      ),
    );
  }

  InlineSpan _char(String c, double p) {
    final eased = Motion.settle.transform(p);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, (1 - eased) * (style.fontSize ?? 20) * 1.1),
          child: Opacity(opacity: eased, child: Text(c, style: style)),
        ),
      ),
    );
  }
}

/// Fades and lifts its child the first time it scrolls into view, so long pages come alive as
/// you move down them instead of animating everything at once off screen.
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const ScrollReveal({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  ScrollPosition? _position;
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.value = 1;
      _shown = true;
      return;
    }
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_shown || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * 0.94) {
      _shown = true;
      _position?.removeListener(_check);
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Motion.settle.transform(_c.value);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 34), child: Transform.scale(scale: 0.97 + 0.03 * t, child: child)));
      },
      child: widget.child,
    );
  }
}

/// A band of light that sweeps across its child once, like light catching a polished surface.
class SheenSweep extends StatefulWidget {
  final Widget child;
  final BorderRadius radius;
  final Duration delay;

  const SheenSweep({super.key, required this.child, this.radius = BorderRadius.zero, this.delay = const Duration(milliseconds: 700)});

  @override
  State<SheenSweep> createState() => _SheenSweepState();
}

class _SheenSweepState extends State<SheenSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && _c.status == AnimationStatus.dismissed) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
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
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.radius,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (_c.value == 0 || _c.value == 1) return const SizedBox.shrink();
                final x = -1.6 + 3.2 * Curves.easeInOut.transform(_c.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 0.6, -1),
                      end: Alignment(x + 0.6, 1),
                      colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                      stops: const [0.35, 0.5, 0.65],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }
}
