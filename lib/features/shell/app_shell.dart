
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
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
      body: GlowBackground(child: SafeArea(bottom: false, child: page)),
      bottomNavigationBar: _GlassNavBar(index: shell.tab, onSelect: shell.goTo),
    );
  }
}

const _items = [
  (AppIcons.dashboard, AppIcons.dashboardOutline, 'Home'),
  (AppIcons.groups, AppIcons.groupsOutline, 'Members'),
  (AppIcons.checkIn, AppIcons.checkInOutline, 'Check-in'),
  (AppIcons.notificationsActive, AppIcons.notifications, 'Reminders'),
  (AppIcons.grid, AppIcons.gridOutline, 'More'),
];

/// The phone tab bar: flat white, a hairline on top, and a short iron marker that slides to the
/// selected tab. Check-in, the desk's most used action, is an iron key in the middle of the bar.
class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _GlassNavBar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final pending = context.select<GymProvider, int>((g) => g.pendingReminderCount);
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (context, box) {
            final slot = box.maxWidth / _items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: Motion.medium,
                  curve: Motion.settle,
                  left: slot * index + slot / 2 - 12,
                  top: 0,
                  child: AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: index == ShellTabs.checkIn ? 0 : 1,
                    child: Container(width: 24, height: 2.5, color: AppColors.text),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: i == ShellTabs.checkIn
                            ? Center(child: _CheckInButton(selected: index == ShellTabs.checkIn, onTap: () => _tap(i)))
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
        radius: 30,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              backgroundColor: AppColors.brand,
              label: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(fontFamily: AppText.bodyFont, fontWeight: FontWeight.w600, fontSize: 10, color: Colors.white)),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontFamily: AppText.bodyFont, color: color, fontSize: 11.5, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
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
        pressedScale: 0.94,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.settle,
          width: selected ? 60 : 52,
          height: 40,
          decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(12)),
          child: const Icon(AppIcons.checkIn, color: Colors.white, size: 22),
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
        color: AppColors.surface,
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
                    color: index == i ? AppColors.surfaceHigh : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Icon(index == i ? _items[i].$1 : _items[i].$2, color: index == i ? AppColors.text : AppColors.muted, size: 22),
                            const SizedBox(width: 14),
                            Expanded(child: Text(_items[i].$3, style: AppText.body.copyWith(fontWeight: index == i ? FontWeight.w600 : FontWeight.w400, color: index == i ? AppColors.text : AppColors.textSecondary))),
                            if (i == ShellTabs.reminders && pending > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(999)),
                                child: Text('$pending', style: const TextStyle(fontFamilyFallback: AppText.fallback, fontFamily: AppText.bodyFont, fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
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
                icon: const Icon(AppIcons.personAdd),
                label: const Text('New admission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
