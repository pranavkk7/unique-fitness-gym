import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_text.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  await Hive.initFlutter('unique_fitness_gym');
  final store = HiveGymStore();
  final gym = GymProvider(store: store);
  DeskNotifications.watch(gym);
  runApp(UniqueFitnessApp(store: store, gym: gym));
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
      child: MaterialApp(
        title: 'Unique Fitness Gym',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: _Splash(splashTime: splashTime),
      ),
    );
  }
}

/// The public web demo is built with `--dart-define=LIVE_DEMO=true`: it opens straight onto the
/// fictional demo data, so a visitor sees a working gym instead of an empty app.
const liveDemo = bool.fromEnvironment('LIVE_DEMO');

/// The logo glows in while saved data loads, then the app fades in.
class _Splash extends StatefulWidget {
  final Duration splashTime;

  const _Splash({required this.splashTime});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  late final Future<void> _ready = Future.wait([_load(), Future<void>.delayed(widget.splashTime)]);

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
          child: done ? const AppShell(key: ValueKey('home')) : const Scaffold(key: ValueKey('splash'), body: GlowBackground(child: _SplashLogo())),
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
            // A red line sweeps out under the logo, like a progress bar.
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
