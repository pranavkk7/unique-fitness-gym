import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/surfaces.dart';
import '../../providers/gym_provider.dart';
import 'shell_controller.dart';

/// The Classic design's phone navigation: a floating frosted bar with a glowing line under the
/// selected tab and a raised red check-in button in the middle.
class ClassicNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<(IconData, IconData, String)> items;

  const ClassicNavBar({super.key, required this.index, required this.onSelect, required this.items});

  @override
  Widget build(BuildContext context) {
    final pending = context.select<GymProvider, int>((g) => g.pendingReminderCount);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SizedBox(
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 6,
              child: LayoutBuilder(builder: (context, box) {
                final slot = box.maxWidth / items.length;
                return Stack(
                  children: [
                    // The glowing line under the selected tab slides between tabs.
                    AnimatedPositioned(
                      duration: Motion.medium,
                      curve: Motion.settle,
                      left: slot * index + slot / 2 - 14,
                      bottom: 7,
                      child: AnimatedOpacity(
                        duration: Motion.fast,
                        opacity: index == ShellTabs.checkIn ? 0 : 1,
                        child: Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.8), blurRadius: 10)],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: i == ShellTabs.checkIn
                                ? const SizedBox()
                                : _ClassicNavItem(
                                    icon: index == i ? items[i].$1 : items[i].$2,
                                    label: items[i].$3,
                                    selected: index == i,
                                    badge: i == ShellTabs.reminders ? pending : 0,
                                    onTap: () => _tap(i),
                                  ),
                          ),
                      ],
                    ),
                  ],
                );
              }),
            ),
            // Raised centre button for the most used action at the desk.
            Align(
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: const Offset(0, -10),
                child: _ClassicCheckInButton(selected: index == ShellTabs.checkIn, onTap: () => _tap(ShellTabs.checkIn)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _tap(int i) {
    HapticFeedback.selectionClick();
    onSelect(i);
  }
}

class _ClassicNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _ClassicNavItem({required this.icon, required this.label, required this.selected, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge pending' : label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              backgroundColor: AppColors.primary,
              label: Text(badge > 99 ? '99+' : '$badge', style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800, fontSize: 10)),
              child: AnimatedScale(scale: selected ? 1.12 : 1, duration: Motion.medium, curve: Motion.pop, child: Icon(icon, color: color, size: 24)),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, color: color, fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ClassicCheckInButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _ClassicCheckInButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Check-in',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.92,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.medium,
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.redGradient,
            border: Border.all(color: AppColors.background, width: 4),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: selected ? 0.8 : 0.45), blurRadius: selected ? 26 : 16, spreadRadius: selected ? 1 : 0)],
          ),
          child: Icon(AppIcons.checkIn, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
