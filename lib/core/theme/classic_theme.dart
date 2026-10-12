import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// The Classic design's theme: dark, with the logo red for actions.
ThemeData buildClassicTheme() {
  final family = AppText.bodyFont;
  final scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.ember,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainer: AppColors.surface,
    error: AppColors.danger,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
  );

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  final buttonText = TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w800, letterSpacing: 0.6, fontSize: 15);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: family,
    fontFamilyFallback: AppText.fallback,
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.small,
      titleMedium: AppText.title,
      labelLarge: buttonText,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.headline,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh,
      labelStyle: AppText.bodyMuted,
      // The floating label turns red only while the field is focused.
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
            fontFamilyFallback: AppText.fallback,
            fontFamily: family,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.error)
                ? AppColors.danger
                : states.contains(WidgetState.focused)
                    ? AppColors.primaryBright
                    : AppColors.textSecondary,
          )),
      hintStyle: AppText.bodyMuted,
      prefixIconColor: AppColors.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.6),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceHigher,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(0, 50),
        side: BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryBright, textStyle: buttonText.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.text)),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.primary,
      side: BorderSide(color: AppColors.border),
      labelStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w700, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.border),
        textStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, fontWeight: FontWeight.w700),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceHigher),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: AppColors.primary, thumbColor: Colors.white, inactiveTrackColor: AppColors.surfaceHigher),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: AppColors.surfaceHigher),
    dividerTheme: DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(iconColor: AppColors.muted, titleTextStyle: AppText.title, subtitleTextStyle: AppText.bodyMuted),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigher,
      contentTextStyle: AppText.body,
      behavior: SnackBarBehavior.floating,
      actionTextColor: AppColors.primaryBright,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      titleTextStyle: AppText.headline.copyWith(fontSize: 22),
      contentTextStyle: AppText.bodyMuted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerBackgroundColor: AppColors.primaryDeep,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.surfaceHigher, borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: family, color: AppColors.text, fontWeight: FontWeight.w600),
    ),
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: AppColors.background),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
