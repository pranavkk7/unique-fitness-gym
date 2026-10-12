import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_text.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'core/theme/skin.dart';
import 'core/utils/notifications.dart';
import 'core/widgets/brand.dart';
import 'core/widgets/surfaces.dart';
import 'data/gym_store.dart';
import 'data/hive_gym_store.dart';
import 'device/demo_access_device.dart';
import 'device/device_service.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/shell_controller.dart';
import 'providers/gym_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('unique_fitness_gym');
  // Open in the design chosen last time, and keep the system bars readable when it changes.
  await Skin.load();
  _systemBars(Skin.current);
  Skin.notifier.addListener(() => _systemBars(Skin.current));
  final store = HiveGymStore();
  final gym = GymProvider(store: store);
  DeskNotifications.watch(gym);
  runApp(UniqueFitnessApp(store: store, gym: gym));
}

/// Dark status-bar icons on Plate & Chalk's light pages, light ones on Classic's dark pages.
void _systemBars(AppSkin skin) {
  final icons = skin == AppSkin.classic ? Brightness.light : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarColor: Colors.transparent,
  ));
}

class UniqueFitnessApp extends StatelessWidget {
  final GymStore store;

  /// Tests pass their own provider (with a fixed clock) and a zero splash time.
  final GymProvider? gym;
  final Duration splashTime;

  /// The simulated Face ID terminal used with demo data (tools pass a quicker one).
  final DemoAccessDevice? demoDevice;

  const UniqueFitnessApp({super.key, required this.store, this.gym, this.splashTime = const Duration(milliseconds: 1600), this.demoDevice});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GymProvider>(create: (_) => gym ?? GymProvider(store: store)),
        ChangeNotifierProvider(create: (_) => ShellController()),
        ChangeNotifierProvider(create: (c) => DeviceService(gym: c.read<GymProvider>(), demoDevice: demoDevice)),
      ],
      // The theme follows the chosen design. The app itself stays mounted, so open pages and the
      // selected tab survive a change of design.
      child: ValueListenableBuilder<AppSkin>(
        valueListenable: Skin.notifier,
        builder: (context, skin, _) => MaterialApp(
          title: 'Unique Fitness Gym',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: _Splash(splashTime: splashTime),
        ),
      ),
    );
  }
}

/// The public web demo is built with `--dart-define=LIVE_DEMO=true`: it opens straight onto the
/// fictional demo data, so a visitor sees a working gym instead of an empty app.
const liveDemo = bool.fromEnvironment('LIVE_DEMO');

/// The logo shows while saved data loads, then the app fades in.
class _Splash extends StatefulWidget {
  final Duration splashTime;

  const _Splash({required this.splashTime});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  late final Future<void> _ready = Future.wait([_load(), Future<void>.delayed(widget.splashTime)]);

  @override
  void initState() {
    super.initState();
    Skin.notifier.addListener(_redraw);
  }

  @override
  void dispose() {
    Skin.notifier.removeListener(_redraw);
    super.dispose();
  }

  // A new design rebuilds the whole app from here down, so every screen picks up the new look.
  void _redraw() => setState(() {});

  Future<void> _load() async {
    final gym = context.read<GymProvider>();
    await gym.init();
    if (liveDemo && !gym.hasMembers) await gym.loadDemoData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        final done = snapshot.connectionState == ConnectionState.done;
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Could not open the gym data.\n${snapshot.error}', textAlign: TextAlign.center))));
        }
        return AnimatedSwitcher(
          duration: Motion.slow,
          switchInCurve: Motion.enter,
          child: done ? AppShell(key: ValueKey('home-${Skin.current.name}')) : const Scaffold(key: ValueKey('splash'), body: GlowBackground(child: _SplashLogo())),
        );
      },
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    if (Skin.classic) return _classic(reduced);
    // The logo settles in on the chalk background; nothing else moves.
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 700),
        curve: Motion.settle,
        builder: (context, t, _) => Opacity(
          opacity: t,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(scale: 0.96 + 0.04 * t, child: const BrandLogo(height: 132)),
              const SizedBox(height: 18),
              Text('Unique Fitness, Pinarayi', style: AppText.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Classic: the logo glows in while a red line sweeps out under it.
  Widget _classic(bool reduced) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: reduced ? Duration.zero : const Duration(milliseconds: 1200),
        curve: Motion.settle,
        builder: (context, t, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.85 + 0.15 * t,
                child: Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35 * t), blurRadius: 80, spreadRadius: 10)]),
                  child: const BrandLogo(height: 150),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 160,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 160 * t, height: 3, decoration: BoxDecoration(gradient: AppColors.redGradient, borderRadius: BorderRadius.circular(2))),
              ),
            ),
            const SizedBox(height: 14),
            Opacity(opacity: t, child: Text('PREMIUM LUXURY FITNESS CENTRE', style: AppText.label.copyWith(letterSpacing: 3.5, color: AppColors.textSecondary))),
          ],
        ),
      ),
    );
  }
}
