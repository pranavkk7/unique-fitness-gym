import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Motion tokens. One set of durations and curves keeps the whole app moving the same way.
class Motion {
  Motion._();

  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 600);
  static const chart = Duration(milliseconds: 900);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const pop = Curves.easeOutBack;
  static const settle = Cubic(0.2, 0.9, 0.25, 1); // quick start, soft landing

  /// Stagger between items entering one after another.
  static const stagger = Duration(milliseconds: 45);

  /// True when the system asks for less motion (accessibility setting). Looping and decorative
  /// animations switch off, and entrances become instant.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

extension EntranceX on Widget {
  /// Fades the widget in and lifts it slightly. Give list items their [index] for a stagger.
  Widget entrance(BuildContext context, {int index = 0, double offset = 0.06, Duration? delay}) {
    if (Motion.reduced(context)) return this;
    final wait = (delay ?? Duration.zero) + Motion.stagger * index.clamp(0, 10);
    return animate(delay: wait).fadeIn(duration: Motion.medium, curve: Motion.enter).slideY(begin: offset, end: 0, duration: Motion.slow, curve: Motion.settle);
  }
}
