import 'access_device.dart';
import 'zk_protocol.dart';

/// Browsers cannot open raw TCP sockets, so the web build cannot talk to the terminal itself.
Future<AccessDevice> connectZkDevice(DeviceConfig config) =>
    Future.error(const ZkException('The Face ID device works from the Android or iPhone app on the gym Wi-Fi, not from a browser.'));
