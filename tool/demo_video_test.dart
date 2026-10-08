// Records the app demo video frame by frame at 120 fps: the real app runs in a phone frame with
// captions beside it, the test clock moves exactly 1/120 s per frame, and every frame is piped
// into ffmpeg. Nothing is screen-recorded, so motion is perfectly even.
//
//   flutter test tool/demo_video_test.dart --timeout none --dart-define=OUT=<path>.mp4
//
// Needs ffmpeg on the PATH. This is a tool, not a test: CI does not run it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/core/theme/app_colors.dart';
import 'package:unique_fitness_gym/core/theme/app_text.dart';
import 'package:unique_fitness_gym/core/widgets/brand.dart';
import 'package:unique_fitness_gym/core/widgets/charts.dart';
import 'package:unique_fitness_gym/core/widgets/member_widgets.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/device/demo_access_device.dart';
import 'package:unique_fitness_gym/main.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

const _fps = 120;
const _canvas = Size(1920, 1080);
const _screen = Size(390, 844); // iPhone 14 logical size
const _scale = 1.13;
final _now = DateTime(2026, 10, 15, 18, 20);
const _out = String.fromEnvironment('OUT', defaultValue: 'build/demo.mp4');
// A quick check of the whole flow: every 12th frame only, at 10 fps.
const _preview = bool.fromEnvironment('PREVIEW');

Future<void> _loadFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final barlow = FontLoader('Barlow');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    barlow.addFont(asset('assets/fonts/Barlow-$w.ttf'));
  }
  await barlow.load();
  final condensed = FontLoader('BarlowCondensed');
  for (final w in ['SemiBold', 'Bold', 'BoldItalic', 'ExtraBoldItalic', 'BlackItalic']) {
    condensed.addFont(asset('assets/fonts/BarlowCondensed-$w.ttf'));
  }
  await condensed.load();
  await (FontLoader('UfgSymbols')
        ..addFont(asset('assets/fonts/UfgSymbols-Regular.ttf'))
        ..addFont(asset('assets/fonts/UfgSymbols-Bold.ttf')))
      .load();
  var root = Platform.environment['FLUTTER_ROOT'] ?? '';
  if (root.isEmpty) {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 5; i++) {
      dir = dir.parent;
    }
    root = dir.path;
  }
  final icons = File('$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  await (FontLoader('MaterialIcons')..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
}

/// One caption beside the phone.
typedef _Caption = ({String tag, String title, String body});

/// Where the finger is, for the touch dot, and whether it is pressed.
class _Touch {
  final Offset at;
  final bool down;
  const _Touch(this.at, this.down);
}

/// Drives the app and writes frames.
class _Recorder {
  final WidgetTester tester;
  final Process ffmpeg;
  final ValueNotifier<_Caption?> caption;
  final ValueNotifier<_Touch?> touch;
  final ValueNotifier<double> progress;
  final double totalSeconds;
  int frame = 0;
  int _pumpedUs = 0;

  _Recorder(this.tester, this.ffmpeg, this.caption, this.touch, this.progress, this.totalSeconds);

  RenderRepaintBoundary get _boundary => tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('stage')));

  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      frame++;
      final target = (frame * 1000000 / _fps).round();
      progress.value = (frame / _fps / totalSeconds).clamp(0, 1);
      await tester.pump(Duration(microseconds: target - _pumpedUs));
      _pumpedUs = target;
      if (_preview && frame % 12 != 0) continue;
      await tester.runAsync(() async {
        final image = await _boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        ffmpeg.stdin.add(bytes!.buffer.asUint8List());
        await ffmpeg.stdin.flush();
      });
    }
  }

  Future<void> seconds(double s) => frames((s * _fps).round());

  void say(String tag, String title, String body) => caption.value = (tag: tag, title: title, body: body);

  /// Moves the touch dot to [finder], presses, and lets the tap play out for [after] seconds.
  Future<void> tap(Finder finder, {double after = 0.6, bool reveal = true}) async {
    // Bring the target into the comfortable middle of the screen first, if it is hidden under the
    // bottom bar or near the edge.
    var at = tester.getCenter(finder.first);
    final top = (_canvas.height - _screen.height * _scale) / 2;
    final bottom = top + _screen.height * _scale;
    if (reveal && at.dy > bottom - 120 * _scale) {
      await scroll((at.dy - (top + bottom) / 2) / _scale, over: 0.7);
      at = tester.getCenter(finder.first);
    }
    touch.value = _Touch(at, false);
    await seconds(0.1);
    touch.value = _Touch(at, true);
    await seconds(0.06);
    await tester.tapAt(at);
    touch.value = _Touch(at, false);
    await seconds(0.1);
    touch.value = null;
    await seconds(after);
  }

  /// The scroll view the user is looking at: the tallest vertical one that can be touched.
  ScrollPosition get _scroll {
    final states = tester.stateList<ScrollableState>(find.byType(Scrollable).hitTestable()).where((s) => s.position.axis == Axis.vertical).toList()
      ..sort((a, b) => b.position.viewportDimension.compareTo(a.position.viewportDimension));
    return states.first.position;
  }

  /// Smooth, eased scroll by [by] pixels over [over] seconds, with a finger dragging up.
  Future<void> scroll(double by, {double over = 1.1}) async {
    final p = _scroll;
    final target = (p.pixels + by).clamp(p.minScrollExtent, p.maxScrollExtent);
    p.animateTo(target, duration: Duration(milliseconds: (over * 1000).round()), curve: Curves.easeInOutCubic);
    await seconds(over + 0.05);
  }

  /// Drags a finger across [from] by [delta] over [over] seconds, frame by frame (chart scrubbing).
  Future<void> drag(Offset from, Offset delta, {double over = 1.2}) async {
    final n = (over * _fps).round();
    touch.value = _Touch(from, true);
    final g = await tester.startGesture(from);
    await seconds(0.1);
    for (var i = 1; i <= n; i++) {
      final t = Curves.easeInOut.transform(i / n);
      final prev = Curves.easeInOut.transform((i - 1) / n);
      await g.moveBy(delta * (t - prev));
      touch.value = _Touch(from + delta * t, true);
      await frames(1);
    }
    await g.up();
    touch.value = null;
    await seconds(0.2);
  }
}

/// The stage: brand background, the phone with the app inside, captions and the touch dot.
class _Stage extends StatelessWidget {
  final Widget app;
  final ValueNotifier<_Caption?> caption;
  final ValueNotifier<_Touch?> touch;
  final ValueNotifier<double> progress;

  const _Stage({required this.app, required this.caption, required this.touch, required this.progress});

  @override
  Widget build(BuildContext context) {
    const bezel = 14.0;
    final phone = Size(_screen.width * _scale + bezel * 2, _screen.height * _scale + bezel * 2);
    return MediaQuery(
      data: const MediaQueryData(size: _canvas),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(children: [
          // Background: near-black with the brand's red glow.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.background),
              child: Stack(children: [
                Positioned(left: -260, top: -300, child: _glow(900, AppColors.primary.withValues(alpha: 0.22))),
                Positioned(right: -320, bottom: -420, child: _glow(1100, AppColors.primaryDeep.withValues(alpha: 0.35))),
              ]),
            ),
          ),
          // The phone.
          Positioned(
            left: 250,
            top: (_canvas.height - phone.height) / 2,
            child: Container(
              width: phone.width,
              height: phone.height,
              padding: const EdgeInsets.all(bezel),
              decoration: BoxDecoration(
                color: const Color(0xFF121216),
                borderRadius: BorderRadius.circular(70),
                border: Border.all(color: const Color(0xFF3B3B45), width: 2.5),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 140, spreadRadius: -10, offset: const Offset(0, 40)),
                  const BoxShadow(color: Color(0xCC000000), blurRadius: 60, offset: Offset(0, 30)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(56),
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: _screen,
                    child: MediaQuery(
                      data: const MediaQueryData(
                        size: _screen,
                        devicePixelRatio: 3,
                        padding: EdgeInsets.only(top: 50, bottom: 30),
                        viewPadding: EdgeInsets.only(top: 50, bottom: 30),
                        textScaler: TextScaler.noScaling,
                      ),
                      child: Stack(children: [
                        Positioned.fill(child: app),
                        const Positioned(left: 0, right: 0, top: 0, height: 50, child: IgnorePointer(child: _StatusBar())),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 8,
                          child: IgnorePointer(child: Center(child: Container(width: 134, height: 5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(3))))),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Captions.
          Positioned(left: 930, top: 110, right: 120, bottom: 110, child: _Captions(caption: caption, progress: progress)),
          // Touch dot.
          Positioned.fill(child: IgnorePointer(child: ValueListenableBuilder<_Touch?>(valueListenable: touch, builder: (_, t, _) => _TouchDot(touch: t)))),
        ]),
      ),
    );
  }

  static Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: AppText.bodyFont, color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700);
    return Stack(children: [
      Align(alignment: const Alignment(0, 0.15), child: Container(width: 122, height: 34, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)))),
      const Padding(
        padding: EdgeInsets.fromLTRB(34, 14, 26, 0),
        child: Row(children: [
          Text('6:20', style: style),
          Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 17, color: Colors.white),
          SizedBox(width: 5),
          Icon(Icons.wifi_rounded, size: 17, color: Colors.white),
          SizedBox(width: 5),
          Icon(Icons.battery_full_rounded, size: 19, color: Colors.white),
        ]),
      ),
    ]);
  }
}

class _TouchDot extends StatelessWidget {
  final _Touch? touch;

  const _TouchDot({required this.touch});

  @override
  Widget build(BuildContext context) {
    final t = touch;
    return Stack(children: [
      AnimatedPositioned(
        duration: const Duration(milliseconds: 90),
        left: (t?.at.dx ?? -100) - 28,
        top: (t?.at.dy ?? -100) - 28,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: t == null ? 0 : 1,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: t?.down ?? false ? 0.82 : 1,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: t?.down ?? false ? 0.38 : 0.22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Captions extends StatelessWidget {
  final ValueNotifier<_Caption?> caption;
  final ValueNotifier<double> progress;

  const _Captions({required this.caption, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const BrandLogo(height: 76),
        const SizedBox(width: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('UNIQUE FITNESS GYM', style: AppText.display.copyWith(fontSize: 34)),
          Text('FRONT DESK APP · PINARAYI', style: AppText.label.copyWith(fontSize: 14, letterSpacing: 3, color: AppColors.primaryBright)),
        ]),
      ]),
      const Spacer(),
      ValueListenableBuilder<_Caption?>(
        valueListenable: caption,
        builder: (_, c, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 520),
          switchInCurve: const Cubic(0.2, 0.9, 0.25, 1),
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(a), child: child),
          ),
          child: c == null
              ? const SizedBox(key: ValueKey('none'), height: 260)
              : SizedBox(
                  key: ValueKey(c.title),
                  height: 260,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                      Container(width: 34, height: 4, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(c.tag.toUpperCase(), style: AppText.label.copyWith(fontSize: 16, letterSpacing: 3.2, color: AppColors.primaryBright)),
                    ]),
                    const SizedBox(height: 14),
                    Text(c.title.toUpperCase(), style: AppText.display.copyWith(fontSize: 76, height: 0.95)),
                    const SizedBox(height: 16),
                    Text(c.body, style: AppText.body.copyWith(fontSize: 25, color: AppColors.textSecondary, height: 1.35)),
                  ]),
                ),
        ),
      ),
      const Spacer(),
      ValueListenableBuilder<double>(
        valueListenable: progress,
        builder: (_, p, _) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(children: [
            Container(height: 4, color: AppColors.surfaceHigher),
            FractionallySizedBox(widthFactor: p, child: Container(height: 4, decoration: const BoxDecoration(gradient: AppColors.redGradient))),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Row(children: [
        Text('Designed & developed by ', style: AppText.body.copyWith(fontSize: 18, color: AppColors.muted)),
        Text('PRANAV KK', style: AppText.headline.copyWith(fontSize: 22, color: AppColors.primaryBright)),
        const Spacer(),
        Text('Flutter · Android · iPhone · Tablet', style: AppText.body.copyWith(fontSize: 18, color: AppColors.muted)),
      ]),
    ]);
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('demo video', (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = _canvas;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Demo data is saved first, so the app opens on the splash and lands on a full dashboard.
    final store = MemoryGymStore();
    final seed = GymProvider(store: store, clock: () => _now);
    await seed.init();
    await seed.loadDemoData();
    final gym = GymProvider(store: store, clock: () => _now);

    final caption = ValueNotifier<_Caption?>(null);
    final touch = ValueNotifier<_Touch?>(null);
    final progress = ValueNotifier<double>(0);
    const total = 31.5;

    // Decode the logos for real before the first frame.
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox()));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(SizedBox));
      await precacheImage(const AssetImage(BrandLogo.darkAsset), context);
      await precacheImage(const AssetImage(BrandLogo.originalAsset), context);
    });

    final ffmpeg = (await tester.runAsync(() => Process.start('ffmpeg', [
          '-y', '-loglevel', 'error',
          '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${_canvas.width.toInt()}x${_canvas.height.toInt()}', '-framerate', _preview ? '10' : '$_fps', '-i', '-',
          // A touch of grain hides gradient banding in the background glow.
          '-vf', 'noise=alls=3:allf=t', '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', _out,
        ])))!;
    ffmpeg.stderr.listen(stderr.add);

    await tester.pumpWidget(RepaintBoundary(
      key: const Key('stage'),
      child: _Stage(
        caption: caption,
        touch: touch,
        progress: progress,
        app: UniqueFitnessApp(store: store, gym: gym, splashTime: const Duration(milliseconds: 1500), demoDevice: DemoAccessDevice(faceEnrolDelay: const Duration(milliseconds: 900), clock: () => _now)),
      ),
    ));

    final r = _Recorder(tester, ffmpeg, caption, touch, progress, total);
    Finder tab(String label) => find.bySemanticsLabel(RegExp('^$label')).last;

    // 1. Splash.
    r.say('Built for a real gym', 'Front desk, reimagined', 'Admissions, Face ID door, payments, reminders and revenue in one premium app.');
    await r.seconds(2.0);

    // 2. Dashboard.
    r.say('01 · Dashboard', 'The desk at a glance', 'Check-ins, money collected, plans ending and dues, counted up live.');
    await r.seconds(1.6);
    await r.scroll(700, over: 1.0);
    r.say('02 · Live charts', 'Rush hours, today', 'Today\'s check-ins against a usual Thursday, hour by hour.');
    await r.seconds(0.9);
    await r.scroll(680, over: 1.0);
    r.say('03 · Income', 'Every month, compared', 'Bars grow in one by one. Drag across them to scrub months.');
    await r.seconds(0.6);
    final bars = tester.getRect(find.byType(RevenueBars).first);
    await r.drag(Offset(bars.left + bars.width * 0.1, bars.center.dy), Offset(bars.width * 0.8, 0), over: 1.1);

    // 3. Revenue report.
    await r.tap(find.text('Full report'), after: 0.7);
    r.say('04 · Owner\'s report', 'Revenue, behind a PIN', 'This year against last, profit, payment split and the busiest hours.');
    await r.tap(find.text('vs last year'), after: 0.8);
    await r.scroll(900, over: 1.0);
    await r.seconds(0.25);
    await r.scroll(700, over: 0.9);
    await r.seconds(0.25);
    await r.tap(find.byTooltip('Back'), after: 0.3);

    // 4. Face ID registration.
    r.say('05 · eSSL Face ID door', 'Face ID, from the app', 'Talks to the door terminal directly. Expired members are stopped at the door.');
    await r.tap(tab('Members'), after: 0.35, reveal: false);
    // The filter chips scroll sideways: swipe them along, then pick "No Face ID".
    final chips = tester.getRect(find.textContaining('Active').first);
    await r.drag(Offset(chips.right + 120, chips.center.dy), const Offset(-330, 0), over: 0.4);
    await r.seconds(0.2);
    await r.tap(find.textContaining('No Face ID'), after: 0.4);
    await r.tap(find.byType(MemberTile).first, after: 0.6);
    await r.tap(find.text('Add Face ID'), after: 2.6);
    await r.tap(find.text('DONE'), after: 0.25);
    await r.tap(find.byTooltip('Back'), after: 0.25);

    // 5. Close the day.
    await r.tap(tab('Home'), after: 0.3, reveal: false);
    await r.scroll(720, over: 0.8);
    await r.tap(find.text('Close\nthe day'), after: 0.5);
    r.say('06 · Close the day', 'Cash, counted', 'Collections by method, the drawer checked to the rupee, report sent to the owner.');
    await r.seconds(0.3);
    await r.tap(find.byType(TextField).first, after: 0.05);
    await tester.enterText(find.byType(TextField).first, '5000');
    await r.seconds(0.9);
    await r.tap(find.byTooltip('Back'), after: 0.3);

    // 6. Shop and PT.
    r.say('07 · More revenue', 'Shop, PT and offers', 'Stock that never goes negative, change for cash, trainer commission.');
    await r.tap(find.text('Shop\nsale'), after: 0.5);
    await r.tap(find.bySemanticsLabel(RegExp('^Whey protein 1 kg, ')).last, after: 0.12);
    await r.tap(find.bySemanticsLabel(RegExp('^BCAA drink, ')).last, after: 0.12);
    await r.tap(find.bySemanticsLabel(RegExp('^Protein bar, ')).last, after: 0.5);
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await r.seconds(0.3);
    await r.tap(find.text('PT\nsession'), after: 1.2);
    await r.tap(find.byTooltip('Back'), after: 0.25);

    // 7. End.
    r.say('Pranav KK', 'Designed & developed', 'Flutter · 95 automated tests · github.com/pranavkk7');
    await r.scroll(-720, over: 0.9);
    await r.seconds(1.5);

    await tester.runAsync(() async {
      await ffmpeg.stdin.close();
      final code = await ffmpeg.exitCode;
      stdout.writeln('ffmpeg exit $code · ${r.frame} frames · ${(r.frame / _fps).toStringAsFixed(1)} s → $_out');
    });
    debugDisableShadows = true;
  }, timeout: Timeout.none);
}
