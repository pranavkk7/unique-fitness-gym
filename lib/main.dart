import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

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
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
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

/// The logo shows while saved data loads, then the app fades in.
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
}
