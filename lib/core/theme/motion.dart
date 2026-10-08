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
  /// Content appears in place. Staggered fade-ins on every list read as decoration, so the app keeps
  /// motion for the dashboard's one opening moment and for responses to what people do.
  Widget entrance(BuildContext context, {int index = 0, double offset = 0.06, Duration? delay}) => this;

  /// The opt-in version of the old entrance, for the one place a reveal helps.
  Widget reveal(BuildContext context, {Duration delay = Duration.zero}) {
    if (Motion.reduced(context)) return this;
    return animate(delay: delay).fadeIn(duration: Motion.medium, curve: Motion.enter).slideY(begin: 0.04, end: 0, duration: Motion.slow, curve: Motion.settle);
  }
}
