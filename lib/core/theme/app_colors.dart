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
/// **Plate & Chalk at night** (dark mode) keeps the same rules on graphite pages with chalk type.
///
/// **Classic.** The original look: the logo's reds (bright #F81818 fading to #A80000) on near-black
/// surfaces, like the gym floor at night.
class AppColors {
  AppColors._();


  /// Picks the value for the look in use: Plate & Chalk by day, Plate & Chalk at night (dark
  /// mode), or Classic.
  static T _p<T>(T day, T night, T classic) => Skin.classic ? classic : (Skin.night ? night : day);

  // Plate colours, darkened just enough to read as text on white (all at least 4.5:1).
  static const _plateGreen = Color(0xFF2E7D4F);
  static const _plateYellow = Color(0xFF9A6700);
  static const _plateBlue = Color(0xFF1F5FBF);
  static const _plateRed = Color(0xFFC8102E);
  static const _iron = Color(0xFF1B1D21);
  static const _slate = Color(0xFF3D4A5C);
  static const _amber = Color(0xFFD99A0B);

  // The same plates lifted for graphite pages (all at least 4.5:1 on the night surface).
  static const _nightGreen = Color(0xFF5BC489);
  static const _nightYellow = Color(0xFFE3AE45);
  static const _nightBlue = Color(0xFF7FA8F5);
  static const _nightRed = Color(0xFFFF6B7A);
  static const _nightSlate = Color(0xFF9AA6B8);
  static const _chalk = Color(0xFFECEDEA);

  static const _classicRed = Color(0xFFF0262E);
  static const _classicBlue = Color(0xFF3987E5);

  // Surfaces. At night the page is graphite and sheets sit a step lighter, so cards still read as
  // sheets without any shadow.
  static Color get background => _p(const Color(0xFFEDEFEB), const Color(0xFF121315), const Color(0xFF09090B));
  static Color get surface => _p(const Color(0xFFFFFFFF), const Color(0xFF1B1D20), const Color(0xFF141418));
  static Color get surfaceHigh => _p(const Color(0xFFF5F6F3), const Color(0xFF23262A), const Color(0xFF1C1C22));
  static Color get surfaceHigher => _p(const Color(0xFFE4E7E2), const Color(0xFF2E3237), const Color(0xFF26262E));
  static Color get border => _p(const Color(0xFFDDE0DA), const Color(0xFF2C2F34), const Color(0x14FFFFFF));
  static Color get borderStrong => _p(const Color(0xFFC6CAC3), const Color(0xFF3B3F45), const Color(0x26FFFFFF));

  // Text
  static Color get text => _p(_iron, _chalk, const Color(0xFFF5F5F7));
  static Color get textSecondary => _p(const Color(0xFF474C55), const Color(0xFFBBBFB9), const Color(0xFFB9B9C2));
  static Color get muted => _p(const Color(0xFF6B7079), const Color(0xFF8F948E), const Color(0xFF8A8A94));

  /// Actions and emphasis: iron by day, chalk at night, red in Classic.
  static Color get primary => _p(_iron, _chalk, _classicRed);
  static Color get primaryBright => _p(_iron, _chalk, const Color(0xFFFF4047));
  static Color get primaryDeep => _p(_iron, _chalk, const Color(0xFF8E0008));

  /// A solid fill for something chosen (a button, a selected tile, the check-in key), and the text
  /// on it. At night the fill is chalk with iron text.
  static Color get ink => _p(_iron, _chalk, _classicRed);
  static Color get onInk => _p(Colors.white, _iron, Colors.white);

  /// The logo red: the logo, alerts and dues.
  static Color get brand => _p(_plateRed, _nightRed, _classicRed);

  // State
  static Color get success => _p(_plateGreen, _nightGreen, const Color(0xFF2FD07F));
  static Color get warning => _p(_plateYellow, _nightYellow, const Color(0xFFFFB020));
  static Color get danger => _p(_plateRed, _nightRed, const Color(0xFFFF4D4F));
  static Color get frozen => _p(_plateBlue, _nightBlue, const Color(0xFF7DD3FC));
  static Color get ember => _p(const Color(0xFFB4530A), const Color(0xFFF08A4B), const Color(0xFFFF6B1A));

  /// WhatsApp actions. Plate & Chalk uses the green plate rather than WhatsApp's neon green.
  static Color get whatsapp => _p(_plateGreen, _nightGreen, const Color(0xFF25D366));

  /// Text and icons drawn on a [whatsapp] button.
  static Color get onWhatsapp => _p(Colors.white, const Color(0xFF0C1D13), Colors.black);

  // Charts. Classic series were checked for colour-blind separation on its dark surface.
  static Color get seriesPrimary => _p(_iron, _chalk, _classicRed);
  static Color get seriesCompare => _p(_plateBlue, _nightBlue, _classicBlue);

  /// Categories. Plate & Chalk keeps red out: there it only ever means money owed or a problem.
  static List<Color> get categorical => _p(
        const [_plateBlue, _slate, _plateGreen, _amber],
        const [_nightBlue, _nightSlate, _nightGreen, _nightYellow],
        const [_classicBlue, Color(0xFFD95926), Color(0xFF199E70), Color(0xFF9085E9)],
      );

  /// One colour per payment method (cash, UPI, card, bank), the same on every screen.
  static List<Color> get payMethods => _p(
        const [_plateGreen, _plateBlue, _amber, _slate],
        const [_nightGreen, _nightBlue, _nightYellow, _nightSlate],
        const [Color(0xFF199E70), _classicBlue, Color(0xFF9085E9), Color(0xFFD95926)],
      );

  /// Bars that are background, not the point.
  static Color get chartContext => _p(const Color(0xFFD3D6D0), const Color(0xFF3A3E44), const Color(0xFF3A3A44));

  /// The one inverted panel per screen (the day's summary, a total to pay). Text on it is white:
  /// flat iron by day, a raised graphite step at night, the logo reds in Classic.
  static LinearGradient get redGradient => _p(
        const LinearGradient(colors: [_iron, _iron]),
        const LinearGradient(colors: [Color(0xFF2A2D32), Color(0xFF2A2D32)]),
        const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF3B3B), Color(0xFFD9141C), Color(0xFF8E0008)]),
      );

  static LinearGradient get surfaceGradient => _p(
        const LinearGradient(colors: [Colors.white, Colors.white]),
        const LinearGradient(colors: [Color(0xFF1B1D20), Color(0xFF1B1D20)]),
        const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A20), Color(0xFF121216)]),
      );
}
