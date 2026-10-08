import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// The Material theme: light chalk pages, white sheets, iron controls, no shadows or glows.
ThemeData buildAppTheme() {
  const family = AppText.bodyFont;
  const scheme = ColorScheme.light(
    primary: AppColors.text,
    onPrimary: Colors.white,
    secondary: AppColors.textSecondary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.surfaceHigh,
    error: AppColors.danger,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
    surfaceTint: Colors.transparent,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );

  const buttonText = TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: -0.1);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: family,
    fontFamilyFallback: AppText.fallback,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.small,
      titleMedium: AppText.title,
      labelLarge: buttonText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.headline,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      labelStyle: AppText.bodyMuted,
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            fontFamilyFallback: AppText.fallback,
            fontFamily: family,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.error) ? AppColors.danger : AppColors.textSecondary,
          )),
      hintStyle: AppText.bodyMuted,
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(AppColors.borderStrong),
      enabledBorder: border(AppColors.borderStrong),
      focusedBorder: border(AppColors.text, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigher,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: buttonShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.borderStrong),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.text, textStyle: buttonText.copyWith(fontSize: 14, decoration: TextDecoration.underline, decorationColor: AppColors.borderStrong)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.text)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.text,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: buttonText,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.text,
      side: const BorderSide(color: AppColors.borderStrong),
      labelStyle: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w500, fontSize: 13.5, color: AppColors.text),
      secondaryLabelStyle: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w500, fontSize: 13.5, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.text,
        selectedForegroundColor: Colors.white,
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: buttonShape,
        textStyle: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w500),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.text : AppColors.borderStrong),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.text : Colors.transparent)),
    sliderTheme: const SliderThemeData(activeTrackColor: AppColors.text, thumbColor: AppColors.text, inactiveTrackColor: AppColors.surfaceHigher, overlayColor: Color(0x141B1D21)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.text, linearTrackColor: AppColors.surfaceHigher),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.textSecondary, titleTextStyle: AppText.title, subtitleTextStyle: AppText.bodyMuted),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: AppText.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      actionTextColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: AppText.headline,
      contentTextStyle: AppText.bodyMuted,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerBackgroundColor: AppColors.text,
      headerForegroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, color: Colors.white, fontWeight: FontWeight.w500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.background),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
