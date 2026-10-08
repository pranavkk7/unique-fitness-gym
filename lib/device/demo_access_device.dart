import 'dart:async';

import 'access_device.dart';
import 'zk_protocol.dart';

/// An in-memory Face ID terminal for the demo and the tests. It behaves like the real one: a new
/// user has no face until someone "looks at the camera" ([faceEnrolDelay] later), disabled users
/// are refused, and the log fills as members walk in ([simulateEntry]).
class DemoAccessDevice implements AccessDevice {
  final Duration faceEnrolDelay;
  final DateTime Function() clock;
  final Map<int, ZkUser> _users = {};
  final Set<int> _faces = {};
  final List<ZkEntry> _log = [];
  final List<Timer> _timers = [];

  DemoAccessDevice({this.faceEnrolDelay = const Duration(seconds: 4), DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  /// Shared simulated device for the demo, so it remembers users across screens.
  static final DemoAccessDevice demo = DemoAccessDevice();

  Iterable<ZkUser> get allUsers => _users.values;

  /// Adds a user who is already enrolled at the door (like the gym's existing members).
  void seedUser(ZkUser u) {
    _users[u.uid] = u;
    _faces.add(u.uid);
  }

  /// A member walks up: the entry is logged only if their face is on file and they are enabled.
  bool simulateEntry(String userId, [DateTime? at]) {
    final u = _users.values.where((u) => u.userId == userId).firstOrNull;
    if (u == null || u.disabled || !_faces.contains(u.uid)) return false;
    _log.add(ZkEntry(userId, at ?? clock()));
    return true;
  }

  void reset() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _users.clear();
    _faces.clear();
    _log.clear();
  }

  @override
  Future<DeviceInfo> info() async => DeviceInfo(users: _users.length, faces: _faces.length, records: _log.length, usersCap: 3000, facesCap: 3000);

  @override
  Future<List<ZkUser>> users() async => _users.values.toList();

  @override
  Future<void> saveUser(ZkUser user) async {
    final isNew = !_users.containsKey(user.uid);
    _users[user.uid] = user;
    // In real life the member now looks at the device; here the face "arrives" a moment later.
    if (isNew) _timers.add(Timer(faceEnrolDelay, () => _faces.add(user.uid)));
  }

  @override
  Future<void> deleteUser(int uid) async {
    _users.remove(uid);
    _faces.remove(uid);
  }

  @override
  Future<List<ZkEntry>> entries() async => List.of(_log);

  @override
  Future<void> setTime(DateTime time) async {}

  @override
  Future<void> close() async {}
}
