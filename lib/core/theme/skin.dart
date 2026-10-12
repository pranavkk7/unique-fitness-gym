import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

/// The two looks the desk can choose from in Settings. Every feature works the same in both; only
/// colour, type, icons and decoration change.
enum AppSkin {
  chalk('Plate & Chalk', 'Light and calm. Colour is only used for status.'),
  classic('Classic', 'The original dark look in the logo red.');

  const AppSkin(this.label, this.description);
  final String label;
  final String description;
}

/// The design in use. Tokens ([AppColors], [AppText], [AppIcons]) read it when a widget builds, and
/// the app rebuilds its whole tree when it changes, so nothing keeps the old look.
class Skin {
  Skin._();

  static final notifier = ValueNotifier<AppSkin>(AppSkin.chalk);

  /// Dark mode for Plate & Chalk. Classic is dark already, so it ignores this.
  static final darkNotifier = ValueNotifier<bool>(false);

  /// Fires when either the design or dark mode changes.
  static final changes = Listenable.merge([notifier, darkNotifier]);

  static AppSkin get current => notifier.value;
  static bool get classic => notifier.value == AppSkin.classic;

  /// Plate & Chalk in dark mode ("night"): graphite pages with chalk-white type.
  static bool get night => !classic && darkNotifier.value;

  /// True whenever the screen is dark, in either design.
  static bool get isDark => classic || night;

  /// Changes whenever the look does; used to rebuild the app in the new look.
  static String get lookKey => '${current.name}-${night ? 'night' : 'day'}';

  // Kept apart from the gym data: it is a choice for this device, not a record of the gym.
  static const _boxName = 'ui_prefs';

  /// Reads the saved choice. Called once before the first frame so the app opens in the right look.
  static Future<void> load() async {
    try {
      final box = await Hive.openBox<String>(_boxName);
      notifier.value = AppSkin.values.asNameMap()[box.get('skin')] ?? AppSkin.chalk;
      darkNotifier.value = box.get('dark') == 'true';
    } catch (_) {
      // Storage unavailable (tests, a private browser window): stay on the default.
    }
  }

  static Future<void> set(AppSkin skin) async {
    notifier.value = skin;
    if (Hive.isBoxOpen(_boxName)) await Hive.box<String>(_boxName).put('skin', skin.name);
  }

  static Future<void> setDark(bool dark) async {
    darkNotifier.value = dark;
    if (Hive.isBoxOpen(_boxName)) await Hive.box<String>(_boxName).put('dark', '$dark');
  }
}
