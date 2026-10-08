// Renders the main screens to PNG files in docs/screenshots with the app's real fonts and the demo
// data at a fixed date, so the pictures are the same on every machine.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// This is a tool, not a test: it lives outside test/ so `flutter test` and CI do not run it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/core/utils/format.dart';
import 'package:unique_fitness_gym/core/widgets/brand.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/main.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

final _now = DateTime(2026, 10, 15, 18, 20); // Thursday evening: the boxing class is live

Future<void> _loadFonts() async {
  Future<ByteData> asset(String path) => rootBundle.load(path);
  final archivo = FontLoader('Archivo');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    archivo.addFont(asset('assets/fonts/Archivo-$w.ttf'));
  }
  await archivo.load();
  final expanded = FontLoader('ArchivoExpanded');
  for (final w in ['Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    expanded.addFont(asset('assets/fonts/ArchivoExpanded-$w.ttf'));
  }
  await expanded.load();
  await (FontLoader('PhosphorRegular')..addFont(asset('assets/fonts/Phosphor-Regular.ttf'))).load();
  await (FontLoader('PhosphorFill')..addFont(asset('assets/fonts/Phosphor-Fill.ttf'))).load();
  await (FontLoader('UfgSymbols')
        ..addFont(asset('assets/fonts/UfgSymbols-Regular.ttf'))
        ..addFont(asset('assets/fonts/UfgSymbols-Bold.ttf')))
      .load();

  // Material icons come from the Flutter SDK cache (flutter_tester lives in <flutter>/bin/cache/...).
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

Future<GymProvider> _open(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  // Final frames only: entrances and count-ups jump to their end state.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final store = MemoryGymStore();
  final gym = GymProvider(store: store, clock: () => _now);
  await tester.pumpWidget(RepaintBoundary(key: const Key('shot'), child: UniqueFitnessApp(store: store, gym: gym, splashTime: Duration.zero)));
  await tester.pumpAndSettle();
  await gym.loadDemoData();
  await tester.pumpAndSettle();
  // Asset images decode asynchronously; load the logo for real before taking pictures.
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold).first);
    await precacheImage(const AssetImage(BrandLogo.darkAsset), context);
  });
  await tester.pumpAndSettle();
  return gym;
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('../docs/screenshots/$name.png'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) => _tap(tester, find.bySemanticsLabel(RegExp('^$label')).last);

Future<void> _scroll(WidgetTester tester, double by) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -by));
  await tester.pumpAndSettle();
}

/// Like testWidgets, but with real blurred shadows (tests normally draw flat ones).
void _capture(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}

/// A running member on a trainer's programme with body checks, for a full-looking profile.
Member _showcaseMember(GymProvider gym) =>
    gym.members.firstWhere((m) => gym.measurementsFor(m.id).length >= 4 && gym.statusOf(m) == MemberStatus.active && gym.visitsInLast(m.id, 30) > 8);

void main() {
  setUpAll(_loadFonts);

  _capture('dashboard', (tester) async {
    await _open(tester);
    await _shot(tester, '01_dashboard');
    await _scroll(tester, 760);
    await _shot(tester, '02_dashboard_actions');
    await _scroll(tester, 640);
    await _shot(tester, '03_dashboard_income');
  });

  _capture('members and profile', (tester) async {
    final gym = await _open(tester);
    await _tab(tester, 'Members');
    await _shot(tester, '04_members');
    final m = _showcaseMember(gym);
    await tester.enterText(find.byType(TextField).first, memberCode(m.number)); // codes are unique, names may not be
    await tester.pumpAndSettle();
    await _tap(tester, find.text(m.name).last);
    await _shot(tester, '05_profile');
    await _scroll(tester, 900);
    await _shot(tester, '06_profile_progress');
    await _scroll(tester, -900);
    await _tap(tester, find.text('Face ID').first);
    await _shot(tester, '07_face_id');
  });

  _capture('admission', (tester) async {
    await _open(tester);
    await _tab(tester, 'Members');
    await _tap(tester, find.byTooltip('New admission'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Ravi Kumar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone (WhatsApp)'), '9847012345');
    await _tap(tester, find.text('Continue'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '176');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '74');
    await _shot(tester, '08_admission_health');
    await _tap(tester, find.text('Continue'));
    await _shot(tester, '09_admission_plan');
    await _tap(tester, find.text('Continue'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Discount'), '500');
    await _tap(tester, find.text('UPI'));
    await _shot(tester, '10_admission_payment');
    await _tap(tester, find.text('Confirm admission'));
    await _shot(tester, '11_admission_done');
  });

  _capture('check-in and reminders', (tester) async {
    await _open(tester);
    await _tab(tester, 'Check-in');
    await _shot(tester, '12_checkin');
    await _tap(tester, find.text('Check in').first);
    await _shot(tester, '13_checkin_result');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await _tab(tester, 'Reminders');
    await _shot(tester, '14_reminders');
  });

  _capture('revenue report', (tester) async {
    await _open(tester);
    await _tab(tester, 'More');
    await _shot(tester, '15_more');
    await _tap(tester, find.text('Revenue & reports'));
    await _shot(tester, '16_revenue');
    await _tap(tester, find.text('vs last year'));
    await _shot(tester, '17_revenue_compare');
    await _scroll(tester, 1500);
    await _shot(tester, '18_revenue_details');
  });

  _capture('front-desk tablet', (tester) async {
    await _open(tester, size: const Size(1280, 800));
    await _shot(tester, '19_tablet_dashboard');
  });

  _capture('tablet portrait', (tester) async {
    await _open(tester, size: const Size(800, 1280));
    await _shot(tester, '29_tablet_portrait');
    await _tab(tester, 'More');
    await tester.scrollUntilVisible(find.text('Close the day'), 250, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Close the day'));
    await _shot(tester, '30_tablet_close_day');
  });

  _capture('desk extras', (tester) async {
    Future<void> more(String item) async {
      await _tab(tester, 'More');
      // The More list is lazy: go back to the top, then scroll until the item is built.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(item), 250, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.text(item));
    }

    // The system back button: closes a sheet or the open page.
    Future<void> back() async {
      await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      await tester.pumpAndSettle();
    }

    await _open(tester);
    await more('Shop & stock');
    await _shot(tester, '20_shop');
    await _tap(tester, find.text('New sale'));
    await _tap(tester, find.bySemanticsLabel(RegExp('^BCAA drink, ')).last);
    await _tap(tester, find.bySemanticsLabel(RegExp('^Protein bar, ')).last);
    await _shot(tester, '21_shop_sale');
    await back();
    await back();
    await more('Personal training');
    await _shot(tester, '22_personal_training');
    await back();
    await more('Close the day');
    await tester.enterText(find.byType(TextField).first, '2000');
    await _shot(tester, '23_close_day');
    await back();
    await more('Offers & referrals');
    await _shot(tester, '24_offers');
    await back();
    await more('Progress reports');
    await _shot(tester, '25_progress_reports');
    await back();
    await more('Feedback');
    await _shot(tester, '26_feedback');
    await back();
    await more('Classes & batches');
    await _tap(tester, find.text('Boxing & Self-Defence').first);
    await _shot(tester, '27_class_batch');
    await back();
    await back();
    await _tap(tester, find.text('Day pass & trial'));
    await _shot(tester, '28_day_pass');
  });

  _capture('face id first-time setup', (tester) async {
    for (final (size, prefix) in [(const Size(390, 844), '31'), (const Size(1280, 800), '33')]) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      final store = MemoryGymStore();
      final gym = GymProvider(store: store, clock: () => _now);
      await tester.pumpWidget(RepaintBoundary(key: const Key('shot'), child: UniqueFitnessApp(key: UniqueKey(), store: store, gym: gym, splashTime: Duration.zero)));
      await tester.pumpAndSettle();
      // A fresh install: no demo data, so the real (not yet connected) device is shown.
      await _tab(tester, 'More');
      await tester.scrollUntilVisible(find.text('Face ID device'), 250, scrollable: find.byType(Scrollable).first);
      await _tap(tester, find.text('Face ID device'));
      await _shot(tester, '${prefix}_face_id_first_time');
      await _tap(tester, find.text('Open setup guide'));
      await _shot(tester, '${prefix == '31' ? '32' : '34'}_face_id_setup_guide');
    }
    tester.view.reset();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
}
