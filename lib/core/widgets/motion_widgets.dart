import 'package:flutter/material.dart';

/// Page titles. Plain text: titles are read many times a day at a front desk, so they appear in
/// place instead of animating in. (Kept as a widget so callers keep one place for titles.)
class RevealText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Duration delay;
  final TextAlign align;

  const RevealText(this.text, {super.key, required this.style, this.delay = Duration.zero, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) => Text(text, style: style, textAlign: align);
}

/// Sections appear in place as you scroll; nothing fades in on its own.
class ScrollReveal extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const ScrollReveal({super.key, required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) => child;
}

/// No decorative sheen: kept so existing callers need no change.
class SheenSweep extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;

  const SheenSweep({super.key, required this.child, this.radius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) => child;
}
