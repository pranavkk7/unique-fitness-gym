import 'package:flutter/material.dart';

/// Colour tokens. The reds come from the Unique Fitness Gym logo (bright #F81818 fading to #A80000);
/// surfaces are near-black like the gym floor at night.
class AppColors {
  AppColors._();

  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF141418);
  static const surfaceHigh = Color(0xFF1C1C22);
  static const surfaceHigher = Color(0xFF26262E);
  static const border = Color(0x14FFFFFF);
  static const borderStrong = Color(0x26FFFFFF);

  static const primary = Color(0xFFF0262E);
  static const primaryBright = Color(0xFFFF4047);
  static const primaryDeep = Color(0xFF8E0008);
  static const ember = Color(0xFFFF6B1A);

  static const text = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFB9B9C2);
  static const muted = Color(0xFF8A8A94);

  // Status colours are reserved for state and always shown with an icon and a label.
  static const success = Color(0xFF2FD07F);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF4D4F);
  static const frozen = Color(0xFF7DD3FC);

  static const whatsapp = Color(0xFF25D366);

  // Chart series, checked for colour-blind separation on [surface] (dataviz validator, dark mode).
  static const seriesPrimary = primary; // this period / income
  static const seriesCompare = Color(0xFF3987E5); // last year / expenses
  static const categorical = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFF9085E9)];
  static const chartContext = Color(0xFF3A3A44); // bars that are background, not the point

  static const redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF3B3B), Color(0xFFD9141C), Color(0xFF8E0008)],
  );

  static const surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A20), Color(0xFF121216)],
  );
}
