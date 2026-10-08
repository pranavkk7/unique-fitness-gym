import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../providers/gym_provider.dart';

/// Schedules the morning summary for the front desk. Scheduled notifications cannot change after
/// they are set, so the next one is worked out from today's data and set again whenever the app
/// opens or the data changes. Phones only: on the web and in tests nothing is scheduled.
class DeskNotifications {
  DeskNotifications._();

  static const _id = 9001;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String _lastScheduled = '';

  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // The gym is in Kerala: the summary follows Indian time whatever the device setting.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    _ready = true;
  }

  /// Keeps the summary up to date: rescheduled a moment after the data stops changing.
  static void watch(GymProvider gym) {
    if (!supported) return;
    Timer? debounce;
    gym.addListener(() {
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 3), () => reschedule(gym));
    });
  }

  /// Sets (or clears) the next morning summary from the current data.
  static Future<void> reschedule(GymProvider gym) async {
    if (!supported || !gym.loaded) return;
    final s = gym.settings;
    try {
      if (!s.dailyNotification || s.demoData) {
        if (_ready) await _plugin.cancel(id: _id);
        _lastScheduled = '';
        return;
      }
      await _init();
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, s.notifyHour);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      final digest = gym.morningDigest(DateTime(at.year, at.month, at.day));
      final key = '${at.toIso8601String()}|${digest?.body}';
      if (key == _lastScheduled) return; // nothing changed since the last schedule
      _lastScheduled = key;
      await _plugin.cancel(id: _id);
      if (digest == null) return;
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: at,
        title: digest.title,
        body: digest.body,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('morning', 'Morning summary', channelDescription: 'Plans ending, dues, birthdays and follow-ups for the day', importance: Importance.high, priority: Priority.high),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      // A notification problem must never stop the desk from working.
      debugPrint('Morning summary not scheduled: $e');
    }
  }
}
