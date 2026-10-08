import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unique_fitness_gym/data/gym_store.dart';
import 'package:unique_fitness_gym/device/access_device.dart';
import 'package:unique_fitness_gym/device/demo_access_device.dart';
import 'package:unique_fitness_gym/device/device_service.dart';
import 'package:unique_fitness_gym/device/zk_client_io.dart';
import 'package:unique_fitness_gym/device/zk_protocol.dart';
import 'package:unique_fitness_gym/models/models.dart';
import 'package:unique_fitness_gym/providers/gym_provider.dart';

String hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

/// A small fake eSSL terminal on localhost that speaks the ZK TCP protocol: password handshake,
/// free sizes, buffered reads (direct and chunked), user writes and deletes, attendance, clock.
class FakeZkDevice {
  final int commKey;
  final Map<int, ZkUser> users = {};
  final List<ZkEntry> log = [];
  int faces = 0;
  DateTime? clock;
  late final ServerSocket server;
  final int session = 4321;
  Uint8List _buffer = Uint8List(0);

  FakeZkDevice({this.commKey = 0});

  int get port => server.port;

  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_serve);
  }

  Future<void> stop() => server.close();

  void _serve(Socket s) {
    final pending = <int>[];
    var authed = commKey == 0;
    s.listen((data) {
      pending.addAll(data);
      while (pending.length >= 8) {
        final len = zkFrameLength(pending);
        if (pending.length < 8 + len) break;
        final packet = pending.sublist(8, 8 + len);
        pending.removeRange(0, 8 + len);
        final b = ByteData.sublistView(Uint8List.fromList(packet));
        final cmd = b.getUint16(0, Endian.little);
        final reply = b.getUint16(6, Endian.little);
        final body = Uint8List.fromList(packet.sublist(8));
        void send(int code, [List<int> payload = const []]) {
          final head = ByteData(8)
            ..setUint16(0, code, Endian.little)
            ..setUint16(4, session, Endian.little)
            ..setUint16(6, reply, Endian.little);
          s.add(zkTcpFrame([...head.buffer.asUint8List(), ...payload]));
        }

        if (cmd == ZkCommand.connect) {
          send(authed ? ZkReply.ok : ZkReply.unauthorized);
        } else if (cmd == ZkCommand.auth) {
          authed = hex(body) == hex(zkCommKey(commKey, session));
          send(authed ? ZkReply.ok : ZkReply.unauthorized);
        } else if (!authed) {
          send(ZkReply.unauthorized);
        } else if (cmd == ZkCommand.getFreeSizes) {
          final d = ByteData(92)
            ..setInt32(16, users.length, Endian.little)
            ..setInt32(32, log.length, Endian.little)
            ..setInt32(60, 3000, Endian.little)
            ..setInt32(80, faces, Endian.little)
            ..setInt32(88, 3000, Endian.little);
          send(ZkReply.ok, d.buffer.asUint8List());
        } else if (cmd == ZkCommand.prepareBuffer) {
          final table = ByteData.sublistView(body).getInt16(1, Endian.little);
          final records = table == ZkCommand.userTempRead
              ? [for (final u in users.values) ...zkPackUser(u)]
              : [for (final e in log) ..._entry40(e)];
          _buffer = Uint8List.fromList([...zkUint32(records.length), ...records]);
          if (table == ZkCommand.userTempRead) {
            send(ZkReply.data, _buffer); // small table: sent at once
          } else {
            send(ZkReply.ok, [0, ...zkUint32(_buffer.length)]); // big table: read in chunks
          }
        } else if (cmd == ZkCommand.readBuffer) {
          final bd = ByteData.sublistView(body);
          final start = bd.getInt32(0, Endian.little), size = bd.getInt32(4, Endian.little);
          final chunk = _buffer.sublist(start, start + size);
          send(ZkReply.prepareData, zkUint32(chunk.length));
          final half = chunk.length ~/ 2; // two DATA frames, then OK
          send(ZkReply.data, chunk.sublist(0, half));
          send(ZkReply.data, chunk.sublist(half));
          send(ZkReply.ok);
        } else if (cmd == ZkCommand.userWrite) {
          final u = zkParseUsers(Uint8List.fromList([...zkUint32(72), ...body]), 1).single;
          users[u.uid] = u;
          send(ZkReply.ok);
        } else if (cmd == ZkCommand.deleteUser) {
          users.remove(ByteData.sublistView(body).getInt16(0, Endian.little));
          send(ZkReply.ok);
        } else if (cmd == ZkCommand.setTime) {
          clock = zkDecodeTime(ByteData.sublistView(body).getUint32(0, Endian.little));
          send(ZkReply.ok);
        } else if (cmd == ZkCommand.exit) {
          send(ZkReply.ok);
          s.close();
        } else {
          send(ZkReply.ok);
        }
      }
    });
  }

  List<int> _entry40(ZkEntry e) {
    final r = ByteData(40)..setUint16(0, 1, Endian.little);
    final out = r.buffer.asUint8List();
    final id = e.userId.codeUnits;
    out.setRange(2, 2 + id.length, id);
    r.setUint32(27, zkEncodeTime(e.time), Endian.little);
    return out;
  }
}

void main() {
  group('protocol bytes match pyzk', () {
    test('packets, checksum and TCP framing', () {
      expect(hex(zkPacket(ZkCommand.connect, const [], 0, 65534)), 'e80317fc00000000');
      expect(hex(zkTcpFrame(zkPacket(ZkCommand.connect, const [], 0, 65534))), '5050827d08000000e80317fc00000000');
      expect(hex(zkPacket(ZkCommand.prepareBuffer, zkBufferRequest(9, fct: 5), 4321, 7)), 'df0536dbe11008000109000500000000000000');
    });

    test('password key', () {
      expect(hex(zkCommKey(0, 4321)), '617d3269');
      expect(hex(zkCommKey(123456, 4321)), '267f32e9');
    });

    test('device time', () {
      final t = DateTime(2026, 10, 15, 18, 20, 5);
      expect(zkEncodeTime(t), 861042005);
      expect(zkDecodeTime(861042005), t);
    });

    test('72-byte user record, including the disabled flag', () {
      const u = ZkUser(uid: 236, userId: '236', name: 'Ravi Kumar', privilege: 1, groupId: '1');
      expect(hex(zkPackUser(u)),
          'ec0001000000000000000052617669204b756d6172000000000000000000000000000000000000003100000000000000323336000000000000000000000000000000000000000000');
      final back = zkParseUsers(Uint8List.fromList([...zkUint32(72), ...zkPackUser(u)]), 1).single;
      expect((back.uid, back.userId, back.name, back.disabled), (236, '236', 'Ravi Kumar', true));
      expect(back.copyWith(disabled: false).privilege, 0);
      expect(const ZkUser(uid: 1, userId: '1', name: 'A', privilege: 14).copyWith(disabled: true).privilege, 15); // role kept
    });

    test('a frame from something that is not a ZK device is rejected', () {
      expect(() => zkFrameLength([0x48, 0x54, 0x54, 0x50, 0, 0, 0, 0]), throwsA(isA<ZkException>()));
    });
  });

  group('TCP client against a fake eSSL terminal', () {
    late FakeZkDevice fake;

    setUp(() async {
      fake = FakeZkDevice(commKey: 123456);
      await fake.start();
    });

    tearDown(() => fake.stop());

    test('logs in with the comm key, writes, reads and deletes users', () async {
      final d = await ZkAccessDevice.connect(DeviceConfig(host: '127.0.0.1', port: fake.port, commKey: 123456));
      await d.saveUser(const ZkUser(uid: 1, userId: '101', name: 'Sneha Pillai'));
      await d.saveUser(const ZkUser(uid: 2, userId: '102', name: 'Rahul Menon', privilege: zkDisabledBit));
      final users = await d.users();
      expect(users.map((u) => (u.userId, u.name, u.disabled)), [('101', 'Sneha Pillai', false), ('102', 'Rahul Menon', true)]);
      await d.deleteUser(1);
      expect((await d.users()).single.userId, '102');
      await d.close();
    });

    test('reads a chunked attendance log and sets the clock', () async {
      fake.users[1] = const ZkUser(uid: 1, userId: '101', name: 'A');
      for (var i = 0; i < 30; i++) {
        fake.log.add(ZkEntry('101', DateTime(2026, 10, 1 + i % 28, 6, i)));
      }
      final d = await ZkAccessDevice.connect(DeviceConfig(host: '127.0.0.1', port: fake.port, commKey: 123456));
      final entries = await d.entries();
      expect(entries.length, 30);
      expect(entries.first.time, DateTime(2026, 10, 1, 6, 0));
      await d.setTime(DateTime(2026, 10, 15, 18, 20, 5));
      expect(fake.clock, DateTime(2026, 10, 15, 18, 20, 5));
      await d.close();
    });

    test('a wrong comm key is reported clearly', () async {
      expect(() => ZkAccessDevice.connect(DeviceConfig(host: '127.0.0.1', port: fake.port, commKey: 1)), throwsA(isA<ZkException>().having((e) => e.message, 'message', contains('password'))));
    });

    test('an unreachable device gives a helpful message', () async {
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = free.port;
      await free.close();
      expect(() => ZkAccessDevice.connect(DeviceConfig(host: '127.0.0.1', port: port)), throwsA(isA<ZkException>().having((e) => e.message, 'message', contains('gym Wi-Fi'))));
    });
  });

  group('device service', () {
    late GymProvider gym;
    late DemoAccessDevice device;
    late DeviceService service;
    var now = DateTime(2026, 10, 15, 18, 0);

    setUp(() async {
      now = DateTime(2026, 10, 15, 18, 0);
      gym = GymProvider(store: MemoryGymStore(), clock: () => now);
      await gym.init();
      await gym.updateSettings(gym.settings.copyWith(deviceHost: '192.168.1.201'));
      device = DemoAccessDevice(faceEnrolDelay: const Duration(milliseconds: 60), clock: () => now);
      service = DeviceService(gym: gym, connector: (_) async => device, demoDevice: device);
    });

    Future<Member> admit(String name, {DateTime? start}) async =>
        (await gym.admit(name: name, phone: '98765${name.length}0000', gender: Gender.male, planId: 'silver-1m', amountPaid: 1500, startDate: start)).member;

    test('registering adds the member to the device and notices the new face', () async {
      final m = await admit('Ravi Kumar');
      final stages = <FaceStage>[];
      final ok = await service.registerFace(m, onStage: (s, _) => stages.add(s), poll: const Duration(milliseconds: 20));
      expect(ok, isTrue);
      expect(stages, [FaceStage.connecting, FaceStage.adding, FaceStage.waitingForFace, FaceStage.done]);
      final linked = gym.memberById(m.id)!;
      expect(linked.deviceUserId, '${m.number}');
      expect(linked.faceEnrolled, isTrue);
      expect(device.allUsers.single.name, 'Ravi Kumar');
    });

    test('a taken device ID is not reused', () async {
      device.seedUser(const ZkUser(uid: 7, userId: '1', name: 'Existing member'));
      final m = await admit('New Person'); // member number 1
      await service.registerFace(m, onStage: (_, _) {}, timeout: Duration.zero);
      expect(gym.memberById(m.id)!.deviceUserId, '2');
      expect(device.allUsers.map((u) => u.uid), containsAll([7, 8]));
    });

    test('sync blocks expired members at the door and lets them back in after renewal', () async {
      final active = await admit('Active One');
      final expired = await admit('Expired One', start: DateTime(2026, 7, 1));
      device.seedUser(const ZkUser(uid: 1, userId: '1', name: 'Active One'));
      device.seedUser(const ZkUser(uid: 2, userId: '2', name: 'Expired One'));
      await gym.linkDevice(active.id, '1', faceEnrolled: true);
      await gym.linkDevice(expired.id, '2', faceEnrolled: true);

      var report = await service.sync();
      expect(report.blocked, 1);
      expect(device.allUsers.firstWhere((u) => u.userId == '2').disabled, isTrue);
      expect(device.simulateEntry('2'), isFalse); // refused at the door
      expect(device.simulateEntry('1'), isTrue);

      await gym.renew(expired.id, planId: 'silver-1m', amountPaid: 1500);
      report = await service.sync();
      expect(report.unblocked, 1);
      expect(device.simulateEntry('2'), isTrue);
    });

    test('door entries become check-ins once per member per day; unknown IDs are counted', () async {
      final m = await admit('Regular');
      device.seedUser(const ZkUser(uid: 1, userId: '1', name: 'Regular'));
      device.seedUser(const ZkUser(uid: 9, userId: '900', name: 'Staff'));
      await gym.linkDevice(m.id, '1', faceEnrolled: true);
      device.simulateEntry('1', DateTime(2026, 10, 15, 6, 10));
      device.simulateEntry('1', DateTime(2026, 10, 15, 7, 40)); // came back in the same morning
      device.simulateEntry('900', DateTime(2026, 10, 15, 6, 0));

      final report = await service.sync();
      expect(report.imported, 1);
      expect(report.unknownIds, 1);
      expect(gym.checkInsToday.single.source, CheckInSource.faceId);
      expect((await service.sync()).imported, 0); // nothing twice
      expect(gym.settings.lastDeviceSync, now);
    });

    test('blocking for unpaid dues is optional', () async {
      final m = (await gym.admit(name: 'Owes Money', phone: '9876500000', gender: Gender.male, planId: 'silver-1m', amountPaid: 500)).member;
      expect(gym.doorAccessAllowed(m), isTrue);
      await gym.updateSettings(gym.settings.copyWith(blockDuesAtDoor: true));
      expect(gym.doorAccessAllowed(gym.memberById(m.id)!), isFalse);
    });

    test('existing device users can be linked and members removed from the device', () async {
      final m = await admit('Sneha Pillai');
      device.seedUser(const ZkUser(uid: 3, userId: '45', name: 'SNEHA PILLAI'));
      final users = await service.deviceUsers();
      expect(nameMatch(users.single.name, m.name), 1.0);
      await service.link(m, users.single);
      expect(gym.memberById(m.id)!.deviceUserId, '45');
      await service.removeFromDevice(gym.memberById(m.id)!);
      expect(device.allUsers, isEmpty);
      expect(gym.memberById(m.id)!.deviceUserId, isNull);
    });

    test('errors are kept for the screen to show', () async {
      final failing = DeviceService(gym: gym, connector: (_) async => throw const ZkException('Could not reach the device'));
      await expectLater(failing.sync(), throwsA(isA<ZkException>()));
      expect(failing.error, 'Could not reach the device');
      expect(failing.busy, isFalse);
    });
  });

  test('sync time text', () {
    final now = DateTime(2026, 10, 15, 18, 0);
    expect(syncAgo(null, now), 'Never synced');
    expect(syncAgo(now.subtract(const Duration(minutes: 3)), now), 'Synced 3 min ago');
  });
}
