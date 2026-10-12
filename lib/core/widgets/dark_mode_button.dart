import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/skin.dart';

/// Switches Plate & Chalk between light and dark. Shows the moon by day and the sun at night, so
/// the icon says where a tap will take you. Hidden in Classic, which is dark already.
class DarkModeButton extends StatelessWidget {
  const DarkModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (Skin.classic) return const SizedBox.shrink();
    final night = Skin.night;
    return IconButton(
      tooltip: night ? 'Light mode' : 'Dark mode',
      onPressed: () {
        HapticFeedback.selectionClick();
        Skin.setDark(!night);
      },
      icon: Icon(night ? AppIcons.sun : AppIcons.moon, color: AppColors.textSecondary),
    );
  }
}
