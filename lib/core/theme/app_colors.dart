import 'package:flutter/material.dart';

import 'skin.dart';

/// Colour tokens for both designs. Each token is read when a widget builds, so a screen follows the
/// design chosen in Settings.
///
/// **Plate & Chalk.** The page is chalk, the type is iron, and colour is used only for state. The four
/// state colours are the competition bumper plates every gym member knows: green 10 kg, yellow 15 kg,
/// blue 20 kg, red 25 kg. Red is also the logo colour, so it is kept for the logo, alerts and money
/// that is owed, never for decoration.
///
/// **Classic.** The original look: the logo's reds (bright #F81818 fading to #A80000) on near-black
/// surfaces, like the gym floor at night.
class AppColors {
  AppColors._();

  static bool get _c => Skin.classic;

  // Plate colours, darkened just enough to read as text on white (all at least 4.5:1).
  static const _plateGreen = Color(0xFF2E7D4F);
  static const _plateYellow = Color(0xFF9A6700);
  static const _plateBlue = Color(0xFF1F5FBF);
  static const _plateRed = Color(0xFFC8102E);
  static const _iron = Color(0xFF1B1D21);
  static const _slate = Color(0xFF3D4A5C);
  static const _amber = Color(0xFFD99A0B);

  static const _classicRed = Color(0xFFF0262E);
  static const _classicBlue = Color(0xFF3987E5);

  // Surfaces
  static Color get background => _c ? const Color(0xFF09090B) : const Color(0xFFEDEFEB);
  static Color get surface => _c ? const Color(0xFF141418) : const Color(0xFFFFFFFF);
  static Color get surfaceHigh => _c ? const Color(0xFF1C1C22) : const Color(0xFFF5F6F3);
  static Color get surfaceHigher => _c ? const Color(0xFF26262E) : const Color(0xFFE4E7E2);
  static Color get border => _c ? const Color(0x14FFFFFF) : const Color(0xFFDDE0DA);
  static Color get borderStrong => _c ? const Color(0x26FFFFFF) : const Color(0xFFC6CAC3);

  // Text
  static Color get text => _c ? const Color(0xFFF5F5F7) : _iron;
  static Color get textSecondary => _c ? const Color(0xFFB9B9C2) : const Color(0xFF474C55);
  static Color get muted => _c ? const Color(0xFF8A8A94) : const Color(0xFF6B7079);

  /// Actions: buttons, selected tabs and chips, the check-in key. Iron in Plate & Chalk, red in Classic.
  static Color get primary => _c ? _classicRed : _iron;

  /// Emphasis text and links.
  static Color get primaryBright => _c ? const Color(0xFFFF4047) : _iron;
  static Color get primaryDeep => _c ? const Color(0xFF8E0008) : _iron;

  /// A solid fill for something chosen (a selected tile), and the text on it.
  static Color get ink => _c ? _classicRed : _iron;
  static Color get onInk => Colors.white;

  /// The logo red: the logo, alerts and dues.
  static Color get brand => _c ? _classicRed : _plateRed;

  // State
  static Color get success => _c ? const Color(0xFF2FD07F) : _plateGreen;
  static Color get warning => _c ? const Color(0xFFFFB020) : _plateYellow;
  static Color get danger => _c ? const Color(0xFFFF4D4F) : _plateRed;
  static Color get frozen => _c ? const Color(0xFF7DD3FC) : _plateBlue;
  static Color get ember => _c ? const Color(0xFFFF6B1A) : const Color(0xFFB4530A);

  /// WhatsApp actions. Plate & Chalk uses the green plate rather than WhatsApp's neon green.
  static Color get whatsapp => _c ? const Color(0xFF25D366) : _plateGreen;

  /// Text and icons drawn on a [whatsapp] button.
  static Color get onWhatsapp => _c ? Colors.black : Colors.white;

  // Charts. Classic series were checked for colour-blind separation on its dark surface.
  static Color get seriesPrimary => _c ? _classicRed : _iron;
  static Color get seriesCompare => _c ? _classicBlue : _plateBlue;

  /// Categories. Plate & Chalk keeps red out: there it only ever means money owed or a problem.
  static List<Color> get categorical => _c
      ? const [_classicBlue, Color(0xFFD95926), Color(0xFF199E70), Color(0xFF9085E9)]
      : const [_plateBlue, _slate, _plateGreen, _amber];

  /// One colour per payment method (cash, UPI, card, bank), the same on every screen.
  static List<Color> get payMethods => _c
      ? const [Color(0xFF199E70), _classicBlue, Color(0xFF9085E9), Color(0xFFD95926)]
      : const [_plateGreen, _plateBlue, _amber, _slate];

  /// Bars that are background, not the point.
  static Color get chartContext => _c ? const Color(0xFF3A3A44) : const Color(0xFFD3D6D0);

  /// The one inverted panel per screen (the day's summary, a total to pay). Text on it is white.
  static LinearGradient get redGradient => _c
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3B3B), Color(0xFFD9141C), Color(0xFF8E0008)])
      : const LinearGradient(colors: [_iron, _iron]);

  static LinearGradient get surfaceGradient => _c
      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A20), Color(0xFF121216)])
      : const LinearGradient(colors: [Colors.white, Colors.white]);
}
