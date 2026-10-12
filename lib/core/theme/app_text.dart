import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'skin.dart';

/// Text styles for both designs. Figures are tabular so counts and amounts line up and never jitter.
///
/// **Plate & Chalk.** One typeface, Archivo, in two widths: expanded for titles and figures (like the
/// numbers stamped on a weight plate) and normal width for everything you read. Sentence case.
///
/// **Classic.** Headlines in Barlow Condensed heavy italics, like the gym's posters; Barlow for the rest.
class AppText {
  AppText._();

  static bool get _c => Skin.classic;

  static String get bodyFont => _c ? 'Barlow' : 'Archivo';
  static String get displayFont => _c ? 'BarlowCondensed' : 'ArchivoExpanded';
  static const _tabular = [FontFeature.tabularFigures()];

  /// Barlow has no rupee sign; this tiny font supplies it.
  static const fallback = ['UfgSymbols'];

  /// Page titles.
  static TextStyle get display => _c
      ? TextStyle(fontFamily: displayFont, fontSize: 36, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 0.95, letterSpacing: 0.3, color: AppColors.text, fontFamilyFallback: fallback)
      : TextStyle(fontFamily: displayFont, fontSize: 28, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -0.8, color: AppColors.text, fontFamilyFallback: fallback);

  /// Section and sheet titles.
  static TextStyle get headline => _c
      ? TextStyle(fontFamily: displayFont, fontSize: 24, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, height: 1.05, letterSpacing: 0.3, color: AppColors.text, fontFamilyFallback: fallback)
      : TextStyle(fontFamily: displayFont, fontSize: 19, fontWeight: FontWeight.w600, height: 1.15, letterSpacing: -0.4, color: AppColors.text, fontFamilyFallback: fallback);

  static TextStyle get title => _c
      ? TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 17, fontWeight: FontWeight.w700, height: 1.2, color: AppColors.text)
      : TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 16, fontWeight: FontWeight.w600, height: 1.25, letterSpacing: -0.1, color: AppColors.text);

  static TextStyle get body => TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: _c ? FontWeight.w500 : FontWeight.w400, height: _c ? 1.4 : 1.45, color: AppColors.text);
  static TextStyle get bodyMuted => TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 14, fontWeight: _c ? FontWeight.w500 : FontWeight.w400, height: _c ? 1.4 : 1.45, color: AppColors.muted);
  static TextStyle get small => TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 12.5, fontWeight: _c ? FontWeight.w600 : FontWeight.w500, height: _c ? 1.3 : 1.35, color: AppColors.textSecondary);

  /// Quiet caption above a figure or a group.
  static TextStyle get label => _c
      ? TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: AppColors.muted)
      : TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.3, color: AppColors.muted);

  /// Large figures.
  static TextStyle get stat => _c
      ? TextStyle(fontFamily: displayFont, fontSize: 34, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, height: 1.0, color: AppColors.text, fontFeatures: _tabular, fontFamilyFallback: fallback)
      : TextStyle(fontFamily: displayFont, fontSize: 30, fontWeight: FontWeight.w600, height: 1.0, letterSpacing: -0.8, color: AppColors.text, fontFeatures: _tabular, fontFamilyFallback: fallback);

  /// Amounts in rows and tables.
  static TextStyle get number => TextStyle(fontFamilyFallback: fallback, fontFamily: bodyFont, fontSize: 15, fontWeight: _c ? FontWeight.w700 : FontWeight.w600, color: AppColors.text, fontFeatures: _tabular);
}
