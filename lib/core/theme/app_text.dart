import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles. Headlines are Barlow Condensed in heavy italics, like the gym's posters; everything
/// else is Barlow. Numbers use tabular figures so counting and tables do not jitter.
class AppText {
  AppText._();

  static const String bodyFont = 'Barlow';
  static const String displayFont = 'BarlowCondensed';
  static const _tabular = [FontFeature.tabularFigures()];

  /// Barlow has no rupee sign; this tiny font supplies it.
  static const fallback = ['UfgSymbols'];

  /// Big slanted poster headline. Use with upper-case text.
  static const display = TextStyle(
    fontFamily: displayFont,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    height: 0.95,
    letterSpacing: 0.3,
    color: AppColors.text,
    fontFamilyFallback: fallback,
  );

  static const headline = TextStyle(
    fontFamily: displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    height: 1.05,
    letterSpacing: 0.3,
    color: AppColors.text,
    fontFamilyFallback: fallback,
  );

  static const title = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.text);
  static const body = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4, color: AppColors.text);
  static const bodyMuted = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: AppColors.muted);
  static const small = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3, color: AppColors.textSecondary);

  /// Small upper-case caption for sections and stats.
  static const label = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: AppColors.muted);

  static const stat = TextStyle(
    fontFamily: displayFont,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    height: 1.0,
    color: AppColors.text,
    fontFeatures: _tabular,
    fontFamilyFallback: fallback,
  );

  /// Upright figures for amounts in rows and tables.
  static const number = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text, fontFeatures: _tabular);
}
