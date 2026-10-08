import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles. One typeface, Archivo, in two widths: expanded for titles and figures (like the
/// numbers stamped on a weight plate) and normal width for everything you read. Sentence case
/// throughout. Figures are tabular so counts and amounts line up and never jitter.
class AppText {
  AppText._();

  static const String bodyFont = 'Archivo';
  static const String displayFont = 'ArchivoExpanded';
  static const _tabular = [FontFeature.tabularFigures()];

  /// Archivo has the rupee sign; the fallback stays for any older text style that still names it.
  static const fallback = ['UfgSymbols'];

  /// Page titles.
  static const display = TextStyle(
    fontFamily: displayFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.8,
    color: AppColors.text,
    fontFamilyFallback: fallback,
  );

  /// Section and sheet titles.
  static const headline = TextStyle(
    fontFamily: displayFont,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.4,
    color: AppColors.text,
    fontFamilyFallback: fallback,
  );

  static const title = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.1, color: AppColors.text);
  static const body = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.text);
  static const bodyMuted = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.muted);
  static const small = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35, color: AppColors.textSecondary);

  /// Quiet caption above a figure or a group. Sentence case, no tracking.
  static const label = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.muted);

  /// Large figures.
  static const stat = TextStyle(
    fontFamily: displayFont,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -0.8,
    color: AppColors.text,
    fontFeatures: _tabular,
    fontFamilyFallback: fallback,
  );

  /// Amounts in rows and tables.
  static const number = TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text, fontFeatures: _tabular);
}
