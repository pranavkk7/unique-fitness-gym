import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/skin.dart';
import 'core/utils/notifications.dart';
import 'core/widgets/splash_logo.dart';
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

/// The opening sequence plays while saved data loads; the app appears once both are done.
class _Splash extends StatefulWidget {
  final Duration splashTime;

  const _Splash({required this.splashTime});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  final _logoDone = Completer<void>();

  // Tests pass a zero splash time and skip the sequence; the app waits for it otherwise, so the
  // opening is never cut off halfway.
  late final Future<void> _ready = Future.wait([
    _load(),
    Future<void>.delayed(widget.splashTime),
    if (widget.splashTime > Duration.zero) _logoDone.future,
  ]);

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
          duration: const Duration(milliseconds: 700),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // The splash eases forward as it fades, and the home screen settles in from just behind
          // it, so the logo seems to open into the app.
          transitionBuilder: (child, animation) {
            final leaving = child.key == const ValueKey('splash');
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: leaving ? 1.06 : 0.97, end: 1.0).animate(animation), child: child),
            );
          },
          child: done
              ? AppShell(key: ValueKey('home-${Skin.current.name}'))
              : Scaffold(
                  key: const ValueKey('splash'),
                  body: GlowBackground(child: SplashLogo(onDone: () {
                    if (!_logoDone.isCompleted) _logoDone.complete();
                  })),
                ),
        );
      },
    );
  }
}
