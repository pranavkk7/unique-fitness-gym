import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/motion.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/sub_page.dart';
import '../../core/widgets/surfaces.dart';
import '../../device/device_service.dart';
import '../../providers/gym_provider.dart';
import '../admission/admission_screen.dart';
import '../checkin/checkin_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../members/members_screen.dart';
import '../more/more_screen.dart';
import '../reminders/reminders_screen.dart';
import 'shell_controller.dart';

/// Phones get a floating glass bar with a raised check-in button; tablets at the front desk get a
/// side rail. Owner areas lock again whenever the app goes to the background.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const wideBreakpoint = 840.0;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onHide: () => context.read<GymProvider>().lock());

  static const _pages = <Widget>[DashboardScreen(), MembersScreen(), CheckInScreen(), RemindersScreen(), MoreScreen()];

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    context.read<DeviceService>().startAutoSync();
    DeskNotifications.onOpen = _openReminders;
  }

  /// The morning summary was tapped: close any open page and show the reminder lists.
  void _openReminders() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<ShellController>().goTo(ShellTabs.reminders);
  }

  @override
  void dispose() {
    if (DeskNotifications.onOpen == _openReminders) DeskNotifications.onOpen = null;
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final wide = MediaQuery.sizeOf(context).width >= AppShell.wideBreakpoint;
    final page = AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(animation), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(shell.tab), child: _pages[shell.tab]),
    );

    if (wide) {
      return Scaffold(
        body: GlowBackground(
          child: Row(
            children: [
              _SideRail(index: shell.tab, onSelect: shell.goTo),
              Expanded(child: SafeArea(left: false, child: page)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: GlowBackground(child: SafeArea(bottom: false, child: page)),
      bottomNavigationBar: _GlassNavBar(index: shell.tab, onSelect: shell.goTo),
    );
  }
}

const _items = [
  (Icons.space_dashboard_rounded, Icons.space_dashboard_outlined, 'Home'),
  (Icons.groups_rounded, Icons.groups_outlined, 'Members'),
  (Icons.how_to_reg_rounded, Icons.how_to_reg_outlined, 'Check-in'),
  (Icons.notifications_active_rounded, Icons.notifications_none_rounded, 'Reminders'),
  (Icons.grid_view_rounded, Icons.grid_view_outlined, 'More'),
];

class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _GlassNavBar({required this.index, required this.onSelect});

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
                final slot = box.maxWidth / _items.length;
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
                        for (var i = 0; i < _items.length; i++)
                          Expanded(
                            child: i == ShellTabs.checkIn
                                ? const SizedBox()
                                : _NavItem(
                                    icon: index == i ? _items[i].$1 : _items[i].$2,
                                    label: _items[i].$3,
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
                child: _CheckInButton(selected: index == ShellTabs.checkIn, onTap: () => _tap(ShellTabs.checkIn)),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.badge, required this.onTap});

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
              label: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800, fontSize: 10)),
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

class _CheckInButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CheckInButton({required this.selected, required this.onTap});

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
          child: const Icon(Icons.how_to_reg_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// The tablet rail: logo, tabs, and a big "New admission" button always within reach.
class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _SideRail({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymProvider>();
    final pending = gym.pendingReminderCount;
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: Color(0xCC0E0E11),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandHeader(branch: gym.settings.branchName),
              const SizedBox(height: 28),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: index == i ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Icon(index == i ? _items[i].$1 : _items[i].$2, color: index == i ? AppColors.primaryBright : AppColors.muted, size: 22),
                            const SizedBox(width: 14),
                            Expanded(child: Text(_items[i].$3, style: AppText.body.copyWith(fontWeight: index == i ? FontWeight.w800 : FontWeight.w600, color: index == i ? AppColors.text : AppColors.textSecondary))),
                            if (i == ShellTabs.reminders && pending > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                                child: Text('$pending', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => openPage(context, const AdmissionScreen()),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('NEW ADMISSION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
