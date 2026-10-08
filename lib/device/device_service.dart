import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/format.dart';
import '../models/models.dart';
import '../providers/gym_provider.dart';
import 'access_device.dart';
import 'demo_access_device.dart';
import 'zk_client_io.dart' if (dart.library.js_interop) 'zk_client_web.dart' as zk;
import 'zk_protocol.dart';

/// What one sync did, shown on the device screen.
class SyncReport {
  final DateTime at;
  final int imported;
  final int unknownIds;
  final int blocked;
  final int unblocked;
  final int deviceUsers;
  final int faces;

  const SyncReport({required this.at, this.imported = 0, this.unknownIds = 0, this.blocked = 0, this.unblocked = 0, this.deviceUsers = 0, this.faces = 0});
}

enum FaceStage { connecting, adding, waitingForFace, done, failed }

/// Keeps the Face ID terminal and the app in step:
/// - door rules: members whose plan has ended (or who owe money, if the gym chooses) are disabled
///   on the terminal, and enabled again the moment they renew;
/// - attendance: door entries come back as check-ins, so reminders and reports stay right;
/// - registration: a new member is added to the terminal from the app, and the app notices when
///   their face has been enrolled.
/// In demo mode it talks to a simulated terminal, so every flow can be shown without hardware.
class DeviceService extends ChangeNotifier {
  final GymProvider gym;
  final DeviceConnector _connect;
  final DemoAccessDevice demoDevice;
  Timer? _auto;
  Timer? _first;
  bool _busy = false;
  String? _error;
  SyncReport? _lastReport;
  DeviceInfo? _lastInfo;

  DeviceService({required this.gym, DeviceConnector? connector, DemoAccessDevice? demoDevice})
      : _connect = connector ?? zk.connectZkDevice,
        demoDevice = demoDevice ?? DemoAccessDevice.demo {
    _wasDemo = gym.settings.demoData;
    gym.addListener(_onGymChanged);
  }

  late bool _wasDemo;

  /// Demo data switched on or off: start the simulated terminal afresh.
  void _onGymChanged() {
    if (gym.settings.demoData == _wasDemo) return;
    _wasDemo = gym.settings.demoData;
    demoDevice.reset();
    _lastReport = null;
    _lastInfo = null;
  }

  bool get busy => _busy;
  String? get error => _error;
  SyncReport? get lastReport => _lastReport;
  DeviceInfo? get lastInfo => _lastInfo;
  bool get isDemo => gym.settings.demoData;
  bool get configured => isDemo || gym.settings.deviceHost.trim().isNotEmpty;
  String get label => isDemo ? 'Demo device' : 'eSSL Face ID · ${gym.settings.deviceHost}';

  DeviceConfig get _config => DeviceConfig(host: gym.settings.deviceHost, port: gym.settings.devicePort, commKey: gym.settings.deviceCommKey);

  Future<AccessDevice> _open() async {
    if (!isDemo) return _connect(_config);
    _seedDemo();
    return demoDevice;
  }

  /// The simulated terminal starts out holding the demo members who are already enrolled, plus a
  /// few door entries from the last hour waiting to be synced.
  void _seedDemo() {
    if (demoDevice.allUsers.isNotEmpty) return;
    for (final m in gym.members.where((m) => m.deviceUserId != null)) {
      demoDevice.seedUser(ZkUser(uid: m.number, userId: m.deviceUserId!, name: _deviceName(m.name)));
    }
    final waiting = gym.members.where((m) => m.deviceUserId != null && gym.doorAccessAllowed(m) && !gym.checkedInToday(m.id)).take(4).toList();
    for (var i = 0; i < waiting.length; i++) {
      demoDevice.simulateEntry(waiting[i].deviceUserId!, gym.now.subtract(Duration(minutes: 6 + i * 11)));
    }
  }

  /// Runs [action] on an open connection and always closes it.
  Future<T> _session<T>(Future<T> Function(AccessDevice d) action, {bool quiet = false}) async {
    if (!quiet) {
      _busy = true;
      _error = null;
      notifyListeners();
    }
    try {
      final d = await _open();
      try {
        return await action(d);
      } finally {
        await d.close();
      }
    } catch (e) {
      _error = e is ZkException ? e.message : '$e';
      rethrow;
    } finally {
      if (!quiet) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<DeviceInfo> test() => _session((d) async => _lastInfo = await d.info());

  /// Applies the door rules, imports new entries (the last 60 days on the first sync) and sets the
  /// terminal's clock from the phone.
  Future<SyncReport> sync() => _session((d) async {
        final users = await d.users();
        var blocked = 0, unblocked = 0;
        for (final u in users) {
          final m = gym.memberByDeviceId(u.userId);
          if (m == null) continue;
          final allow = gym.doorAccessAllowed(m);
          if (u.disabled == !allow) continue;
          await d.saveUser(u.copyWith(disabled: !allow));
          allow ? unblocked++ : blocked++;
        }
        final since = gym.settings.lastDeviceSync?.subtract(const Duration(days: 1)) ?? gym.today.subtract(const Duration(days: 60));
        final entries = [for (final e in await d.entries()) if (e.time.isAfter(since)) (userId: e.userId, time: e.time)];
        final result = await gym.importDeviceEntries(entries);
        if (gym.settings.syncDeviceClock) {
          try {
            await d.setTime(gym.now);
          } catch (_) {
            // Some models refuse the clock command; attendance still works.
          }
        }
        final info = _lastInfo = await d.info();
        await gym.updateSettings(gym.settings.copyWith(lastDeviceSync: gym.now));
        return _lastReport = SyncReport(
          at: gym.now,
          imported: result.imported,
          unknownIds: result.unknown,
          blocked: blocked,
          unblocked: unblocked,
          deviceUsers: info.users,
          faces: info.faces,
        );
      });

  /// Users on the terminal, for linking the gym's existing members.
  Future<List<ZkUser>> deviceUsers() => _session((d) => d.users());

  Future<void> link(Member m, ZkUser u) => gym.linkDevice(m.id, u.userId, faceEnrolled: true);

  /// Adds the member to the terminal, then waits (up to [timeout]) for the terminal's face count
  /// to go up, which means the member has looked at the camera and is enrolled.
  /// [onStage] reports progress; [cancelled] lets the screen stop waiting.
  Future<bool> registerFace(
    Member member, {
    required void Function(FaceStage stage, String? deviceId) onStage,
    bool Function()? cancelled,
    Duration timeout = const Duration(minutes: 2),
    Duration poll = const Duration(seconds: 2),
  }) async {
    onStage(FaceStage.connecting, member.deviceUserId);
    try {
      return await _session((d) async {
        onStage(FaceStage.adding, member.deviceUserId);
        final users = await d.users();
        var deviceId = member.deviceUserId;
        if (deviceId == null || !users.any((u) => u.userId == deviceId)) {
          final taken = users.map((u) => u.userId).toSet();
          deviceId = taken.contains('${member.number}')
              ? '${users.map((u) => int.tryParse(u.userId) ?? 0).fold(member.number, max) + 1}'
              : '${member.number}';
          final uid = users.map((u) => u.uid).fold(0, max) + 1;
          await d.saveUser(ZkUser(uid: uid, userId: deviceId, name: _deviceName(member.name), privilege: gym.doorAccessAllowed(member) ? 0 : zkDisabledBit));
          await gym.linkDevice(member.id, deviceId, faceEnrolled: false);
        }
        final baseline = (await d.info()).faces;
        onStage(FaceStage.waitingForFace, deviceId);
        final stop = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(stop)) {
          if (cancelled?.call() ?? false) return false;
          await Future<void>.delayed(poll);
          if ((await d.info()).faces > baseline) {
            await gym.linkDevice(member.id, deviceId, faceEnrolled: true);
            onStage(FaceStage.done, deviceId);
            return true;
          }
        }
        return false;
      });
    } catch (_) {
      onStage(FaceStage.failed, member.deviceUserId);
      return false;
    }
  }

  /// Staff confirm by hand when the face count cannot be read on their model.
  Future<void> confirmFace(Member m) => gym.linkDevice(m.id, m.deviceUserId, faceEnrolled: true);

  /// Deletes the member (and their face) from the terminal and unlinks them.
  Future<void> removeFromDevice(Member m) async {
    final id = m.deviceUserId;
    if (id == null) return;
    await _session((d) async {
      final u = (await d.users()).where((u) => u.userId == id).firstOrNull;
      if (u != null) await d.deleteUser(u.uid);
    });
    await gym.linkDevice(m.id, null);
  }

  /// Syncs every few minutes while the app is open.
  void startAutoSync({Duration every = const Duration(minutes: 5), Duration first = const Duration(seconds: 4)}) {
    _auto?.cancel();
    // A first sync shortly after the app opens, then every few minutes.
    _first?.cancel();
    _first = Timer(first, () {
      if (configured && !_busy) unawaited(sync().then<void>((_) {}, onError: (_) {}));
    });
    _auto = Timer.periodic(every, (_) {
      if (configured && !_busy) unawaited(sync().then<void>((_) {}, onError: (_) {}));
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _first?.cancel();
    gym.removeListener(_onGymChanged);
    super.dispose();
  }
}

/// Terminals show plain ASCII names of up to 24 characters.
String _deviceName(String name) {
  final ascii = name.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
  return ascii.length > 24 ? ascii.substring(0, 24) : ascii;
}

/// How close a device name is to a member name (0 to 1), for suggesting links.
double nameMatch(String a, String b) {
  final x = a.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
  final y = b.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / max(x.length, y.length);
}

/// "2 min ago" style text for the last sync.
String syncAgo(DateTime? at, DateTime now) {
  if (at == null) return 'Never synced';
  final m = now.difference(at).inMinutes;
  if (m < 1) return 'Synced just now';
  if (m < 60) return 'Synced $m min ago';
  if (sameDay(at, now)) return 'Synced at ${formatTime(at)}';
  return 'Synced ${formatDayMonth(at)}';
}
