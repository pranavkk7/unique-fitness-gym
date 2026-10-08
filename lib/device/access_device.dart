import 'zk_protocol.dart';

/// Where the Face ID terminal is on the gym network.
class DeviceConfig {
  final String host;
  final int port;
  final int commKey; // the device's communication password, 0 when none is set

  const DeviceConfig({required this.host, this.port = 4370, this.commKey = 0});

  bool get isSet => host.trim().isNotEmpty;
}

/// What the terminal reports about itself.
class DeviceInfo {
  final int users;
  final int faces;
  final int records;
  final int usersCap;
  final int facesCap;

  const DeviceInfo({required this.users, required this.faces, required this.records, this.usersCap = 0, this.facesCap = 0});

  factory DeviceInfo.fromSizes(ZkSizes s) => DeviceInfo(users: s.users, faces: s.faces, records: s.records, usersCap: s.usersCap, facesCap: s.facesCap);
}

/// A Face ID terminal the app can manage. [ZkAccessDevice] talks to a real eSSL/ZKTeco device;
/// [DemoAccessDevice] simulates one for the demo and for tests.
abstract class AccessDevice {
  Future<DeviceInfo> info();

  Future<List<ZkUser>> users();

  /// Creates the user, or updates the one in the same slot ([ZkUser.uid]).
  Future<void> saveUser(ZkUser user);

  Future<void> deleteUser(int uid);

  /// Every door entry stored on the device.
  Future<List<ZkEntry>> entries();

  Future<void> setTime(DateTime time);

  Future<void> close();
}

/// Opens a connection. The real implementation needs a phone or tablet on the gym Wi-Fi.
typedef DeviceConnector = Future<AccessDevice> Function(DeviceConfig config);
