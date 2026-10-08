import 'package:flutter/material.dart';

/// Colour tokens: "plate and chalk".
///
/// The page is chalk, the type is iron, and colour is used only for state. The four state colours are
/// the competition bumper plates every gym member knows: green 10 kg, yellow 15 kg, blue 20 kg, red
/// 25 kg. Red is also the gym's logo colour, so it is kept for the logo, for alerts and for money that
/// is owed, never for decoration.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = Color(0xFFEDEFEB); // chalk
  static const surface = Color(0xFFFFFFFF); // a sheet of the register
  static const surfaceHigh = Color(0xFFF5F6F3); // fields and quiet fills on a sheet
  static const surfaceHigher = Color(0xFFE4E7E2); // tracks, disabled
  static const border = Color(0xFFDDE0DA); // hairline rule
  static const borderStrong = Color(0xFFC6CAC3);

  // Ink
  static const text = Color(0xFF1B1D21); // iron
  static const textSecondary = Color(0xFF474C55);
  static const muted = Color(0xFF6B7079); // steel (4.8:1 on white)

  /// Actions are iron: buttons, selected tabs and chips, the check-in key.
  static const primary = text;

  /// Emphasis text and links: also iron, so nothing on a page shouts unless it is a state.
  static const primaryBright = text;
  static const primaryDeep = text;

  // Plate colours, darkened just enough to read as text on white (all at least 4.5:1).
  static const plateGreen = Color(0xFF2E7D4F);
  static const plateYellow = Color(0xFF9A6700);
  static const plateBlue = Color(0xFF1F5FBF);
  static const plateRed = Color(0xFFC8102E);

  /// The logo red: the logo, alerts and dues.
  static const brand = plateRed;

  static const success = plateGreen;
  static const warning = plateYellow;
  static const danger = plateRed;
  static const frozen = plateBlue;
  static const ember = Color(0xFFB4530A);

  // WhatsApp actions use the green plate rather than the app's neon brand green.
  static const whatsapp = plateGreen;

  // Charts: this period in iron, the comparison in plate blue; categories follow the plates.
  static const seriesPrimary = text;
  static const seriesCompare = plateBlue;
  // Red stays out of categories: on this app it only ever means money owed or a problem.
  static const categorical = [plateBlue, Color(0xFF3D4A5C), plateGreen, Color(0xFFD99A0B)];

  /// One colour per payment method (cash, UPI, card, bank), the same on every screen.
  static const payMethods = [plateGreen, plateBlue, Color(0xFFD99A0B), Color(0xFF3D4A5C)];
  static const chartContext = Color(0xFFD3D6D0);

  /// The one inverted panel per screen (the day's summary, a total to pay): flat iron, no glow.
  static const redGradient = LinearGradient(colors: [Color(0xFF1B1D21), Color(0xFF1B1D21)]);

  /// Plain white sheets. Kept as a gradient so existing callers need no change.
  static const surfaceGradient = LinearGradient(colors: [surface, surface]);
}
