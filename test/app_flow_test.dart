import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/core/utils/notifications.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/main.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

final _now = DateTime(2026, 10, 15, 18, 0); // a Thursday evening

/// Opens the app on a phone-sized screen with a fixed clock and the system "reduce motion"
/// setting on, so looping animations stop and every screen settles.
Future<GymProvider> _launch(WidgetTester tester, {bool demo = false, Size size = const Size(1170, 2532)}) async {
  // flutter_test draws text with the wide "Ahem" font, which makes harmless overflows that real
  // fonts do not. Layout is checked on the real web build and in the screenshot tool instead.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final store = MemoryGymStore();
  final gym = GymProvider(store: store, clock: () => _now);
  await tester.pumpWidget(UniqueFitnessApp(store: store, gym: gym, splashTime: Duration.zero));
  await tester.pumpAndSettle();
  if (demo) {
    await gym.loadDemoData();
    await tester.pumpAndSettle();
  }
  return gym;
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^$label')).last);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fresh install shows the welcome card', (tester) async {
    await _launch(tester);
    expect(find.textContaining('WELCOME TO'), findsOneWidget);
    expect(find.text('LOAD DEMO'), findsOneWidget);
    expect(find.text('PINARAYI'), findsOneWidget);
  });

  testWidgets('demo data fills the dashboard', (tester) async {
    final gym = await _launch(tester, demo: true);
    expect(find.text('TODAY AT THE DESK'), findsOneWidget);
    expect(find.text('ACTIVE MEMBERS'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('reminders ready to send'));
    expect(find.textContaining('reminders ready to send'), findsOneWidget);
    expect(find.text('RUSH HOURS TODAY'), findsOneWidget);
    expect(gym.pendingReminderCount, greaterThan(0));
  });

  testWidgets('a new admission goes through four steps and celebrates', (tester) async {
    final gym = await _launch(tester);
    await tester.tap(find.text('NEW ADMISSION').first);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4 · Personal'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Ravi Kumar');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone (WhatsApp)'), '9847012345');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 4 · Health & goals'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Height'), '175');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight'), '70');
    await tester.pumpAndSettle();
    expect(find.text('HEALTHY'), findsOneWidget); // live BMI
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 4 · Plan'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Silver 1 Month')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Step 4 of 4 · Payment'), findsOneWidget);
    expect(find.text('₹1,500'), findsWidgets); // the plan price is the whole bill: no joining fee
    expect(find.textContaining('Admission fee'), findsNothing);
    await tester.tap(find.text('CONFIRM ADMISSION'));
    await tester.pumpAndSettle();

    expect(find.textContaining('UNIQUE FAMILY'), findsOneWidget);
    final m = gym.members.single;
    expect(m.name, 'Ravi Kumar');
    expect(m.balanceDue, 0);
    expect(gym.paymentsFor(m.id).map((p) => p.receiptNo).toSet().length, 1);
    expect(find.text('SEND WELCOME ON WHATSAPP'), findsOneWidget);
  });

  testWidgets('admission step 1 checks the name and phone', (tester) async {
    final gym = await _launch(tester);
    await tester.tap(find.text('NEW ADMISSION').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text("Enter the member's name"), findsOneWidget);
    expect(find.text('Enter a valid 10-digit number'), findsOneWidget);
    expect(find.text('Step 1 of 4 · Personal'), findsOneWidget);
    expect(gym.members, isEmpty);
  });

  testWidgets('admission warns when the phone number is already registered', (tester) async {
    final gym = await _launch(tester);
    await gym.admit(name: 'Sneha Pillai', phone: '9847012345', gender: Gender.female, planId: 'silver-1m');
    await tester.pumpAndSettle();
    await _tab(tester, 'Members');
    await tester.tap(find.byTooltip('New admission'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Someone Else');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone (WhatsApp)'), '9847012345');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Already registered: Sneha Pillai'), findsOneWidget);
  });

  testWidgets('the check-in tab records a visit and shows the result card', (tester) async {
    final gym = await _launch(tester);
    await gym.admit(name: 'Sneha Pillai', phone: '9876543210', gender: Gender.female, planId: 'silver-1m', amountPaid: 2000);
    await tester.pumpAndSettle();
    await _tab(tester, 'Check-in');
    await _scrollTo(tester, find.text('CHECK IN'));
    await tester.tap(find.text('CHECK IN'));
    await tester.pumpAndSettle();

    expect(find.text('CHECKED IN'), findsOneWidget);
    expect(find.text('SNEHA PILLAI'), findsOneWidget);
    expect(gym.checkInsToday, hasLength(1));
    await tester.pump(const Duration(seconds: 3)); // the card closes itself
    await tester.pumpAndSettle();
    expect(find.text('CHECKED IN'), findsNothing);
  });

  testWidgets('an expired member is stopped at check-in with a renew option', (tester) async {
    final gym = await _launch(tester);
    await gym.admit(name: 'Old Member', phone: '9876543210', gender: Gender.male, planId: 'silver-1m', startDate: DateTime(2026, 7, 1));
    await tester.pumpAndSettle();
    await _tab(tester, 'Check-in');
    await tester.tap(find.text('Show expired members'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('CHECK IN'));
    await tester.tap(find.text('CHECK IN'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBERSHIP EXPIRED'), findsOneWidget);
    expect(find.text('RENEW NOW'), findsOneWidget);
    await tester.tap(find.text('Allow once'));
    await tester.pumpAndSettle();
    expect(gym.checkInsToday, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('send all walks through the reminder list one person at a time', (tester) async {
    final gym = await _launch(tester);
    for (final (name, start) in [('Asha Nair', DateTime(2026, 9, 17)), ('Binu Raj', DateTime(2026, 9, 19))]) {
      await gym.admit(name: name, phone: '98765${name.length}3210', gender: Gender.male, planId: 'silver-1m', startDate: start, amountPaid: 2000);
    }
    await tester.pumpAndSettle();
    await _tab(tester, 'Reminders');
    expect(find.text('SEND ALL 2'), findsOneWidget);
    await tester.tap(find.text('SEND ALL 2'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('ASHA NAIR'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('BINU RAJ'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('0 OF 2 SENT'), findsOneWidget);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('SEND ALL 2'), findsOneWidget); // skipped people stay on the list
  });

  testWidgets('with an owner PIN, revenue stays locked until the PIN is entered', (tester) async {
    final gym = await _launch(tester, demo: true);
    await gym.setPin('2580');
    gym.lock();
    await tester.pumpAndSettle();
    expect(find.text('Income is visible to the owner only'), findsNothing); // not scrolled yet
    await _tab(tester, 'More');
    await tester.tap(find.text('Revenue & reports'));
    await tester.pumpAndSettle();
    expect(find.text('OWNER PIN'), findsOneWidget);

    Future<void> enter(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.text(d).last);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    await enter('1111');
    expect(gym.ownerUnlocked, isFalse);
    expect(find.text('OWNER PIN'), findsOneWidget);
    await enter('2580');
    expect(gym.ownerUnlocked, isTrue);
    expect(find.text('MONTHLY INCOME'), findsOneWidget);
  });

  testWidgets('the bottom bar reaches every tab', (tester) async {
    await _launch(tester, demo: true);
    await _tab(tester, 'Members');
    expect(find.text('MEMBERS'), findsOneWidget);
    await _tab(tester, 'Check-in');
    expect(find.text('Face ID at the door'), findsOneWidget);
    await _tab(tester, 'Reminders');
    expect(find.text('REMINDERS'), findsOneWidget);
    await _tab(tester, 'More');
    expect(find.text('Revenue & reports'), findsOneWidget);
    await _tab(tester, 'Home');
    expect(find.text('TODAY AT THE DESK'), findsOneWidget);
  });

  testWidgets('a tablet gets the side rail instead of the bottom bar', (tester) async {
    await _launch(tester, demo: true, size: const Size(3840, 2400));
    expect(find.text('NEW ADMISSION'), findsWidgets);
    expect(find.text('UNIQUE FITNESS'), findsOneWidget);
    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('MEMBERS'), findsOneWidget);
  });

  testWidgets('tapping the morning summary closes open pages and shows the reminders', (tester) async {
    await _launch(tester, demo: true);
    await _tab(tester, 'More');
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('PAYMENTS'), findsOneWidget);

    DeskNotifications.onOpen!(); // what the notification plugin calls on a tap
    await tester.pumpAndSettle();
    expect(find.text('PAYMENTS'), findsNothing);
    expect(find.text('REMINDERS'), findsOneWidget);
  });
}
