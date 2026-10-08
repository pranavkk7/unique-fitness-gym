/// The ZKTeco "standalone SDK" network protocol spoken by eSSL and ZKTeco face and fingerprint
/// terminals (TCP port 4370). Pure functions only, so every byte layout here is unit-tested.
///
/// An independent Dart implementation of the protocol as documented by the community (the
/// open-source pyzk project and the zk-protocol notes). The tests check these bytes against
/// reference packets produced by pyzk.
library;

import 'dart:convert';
import 'dart:typed_data';

class ZkCommand {
  ZkCommand._();

  static const connect = 1000;
  static const exit = 1001;
  static const auth = 1102;
  static const refreshData = 1013;
  static const getFreeSizes = 50;
  static const userWrite = 8;
  static const userTempRead = 9;
  static const attLogRead = 13;
  static const deleteUser = 18;
  static const getTime = 201;
  static const setTime = 202;
  static const prepareBuffer = 1503;
  static const readBuffer = 1504;
  static const freeData = 1502;

  static const fctUser = 5;
}

class ZkReply {
  ZkReply._();

  static const ok = 2000;
  static const error = 2001;
  static const data = 1501;
  static const prepareData = 1500;
  static const unauthorized = 2005;
}

const _ushrtMax = 65535;
const _tcpMagic1 = 0x5050;
const _tcpMagic2 = 0x7D82;

/// Role values are even (0 user, 2 enroller, 6 manager, 14 admin); the lowest bit marks a
/// disabled user, which the terminal refuses at the door while keeping their face on file.
const zkDisabledBit = 0x01;

class ZkException implements Exception {
  final String message;

  const ZkException(this.message);

  @override
  String toString() => 'ZkException: $message';
}

/// 16-bit ones'-complement style checksum over the packet header and data (from zkemsdk.c).
int zkChecksum(List<int> p) {
  var sum = 0;
  var i = 0;
  while (p.length - i > 1) {
    sum += p[i] | (p[i + 1] << 8);
    i += 2;
    if (sum > _ushrtMax) sum -= _ushrtMax;
  }
  if (p.length - i == 1) sum += p.last;
  while (sum > _ushrtMax) {
    sum -= _ushrtMax;
  }
  sum = -sum - 1; // bitwise NOT, written arithmetically so it behaves the same on every platform
  while (sum < 0) {
    sum += _ushrtMax;
  }
  return sum;
}

/// Command header plus data. The checksum covers the header with the current [replyId]; the
/// packet carries replyId + 1, exactly as the terminals expect.
Uint8List zkPacket(int command, List<int> data, int sessionId, int replyId) {
  final head = ByteData(8)
    ..setUint16(0, command, Endian.little)
    ..setUint16(2, 0, Endian.little)
    ..setUint16(4, sessionId, Endian.little)
    ..setUint16(6, replyId, Endian.little);
  final checksum = zkChecksum([...head.buffer.asUint8List(), ...data]);
  var next = replyId + 1;
  if (next >= _ushrtMax) next -= _ushrtMax;
  head
    ..setUint16(2, checksum, Endian.little)
    ..setUint16(6, next, Endian.little);
  return Uint8List.fromList([...head.buffer.asUint8List(), ...data]);
}

/// Prefixes a packet with the 8-byte TCP header (magic + length).
Uint8List zkTcpFrame(List<int> packet) {
  final top = ByteData(8)
    ..setUint16(0, _tcpMagic1, Endian.little)
    ..setUint16(2, _tcpMagic2, Endian.little)
    ..setUint32(4, packet.length, Endian.little);
  return Uint8List.fromList([...top.buffer.asUint8List(), ...packet]);
}

/// Length of the packet in a TCP frame header, or throws if the header is not a ZK frame.
int zkFrameLength(List<int> top) {
  final b = ByteData.sublistView(Uint8List.fromList(top.sublist(0, 8)));
  if (b.getUint16(0, Endian.little) != _tcpMagic1 || b.getUint16(2, Endian.little) != _tcpMagic2) {
    throw const ZkException('Not a ZK packet (wrong device or port?)');
  }
  return b.getUint32(4, Endian.little);
}

class ZkResponse {
  final int code;
  final int sessionId;
  final int replyId;
  final Uint8List data;

  const ZkResponse(this.code, this.sessionId, this.replyId, this.data);

  bool get ok => code == ZkReply.ok || code == ZkReply.data || code == ZkReply.prepareData;

  /// Parses a packet (without the TCP header).
  factory ZkResponse.parse(List<int> packet) {
    if (packet.length < 8) throw const ZkException('Short reply from device');
    final b = ByteData.sublistView(Uint8List.fromList(packet));
    return ZkResponse(b.getUint16(0, Endian.little), b.getUint16(4, Endian.little), b.getUint16(6, Endian.little), Uint8List.fromList(packet.sublist(8)));
  }
}

/// Scrambles the device's communication password with the session id (MakeKey in commpro.c).
Uint8List zkCommKey(int key, int sessionId, {int ticks = 50}) {
  var k = 0;
  for (var i = 0; i < 32; i++) {
    k = (key & (1 << i)) != 0 ? (k << 1 | 1) : k << 1;
  }
  k = (k + sessionId) & 0xFFFFFFFF;
  final b = [k & 0xff, (k >> 8) & 0xff, (k >> 16) & 0xff, (k >> 24) & 0xff];
  final x = [b[0] ^ 0x5A, b[1] ^ 0x4B, b[2] ^ 0x53, b[3] ^ 0x4F]; // "ZKSO"
  final swapped = [x[2], x[3], x[0], x[1]];
  final t = ticks & 0xff;
  return Uint8List.fromList([swapped[0] ^ t, swapped[1] ^ t, t, swapped[3] ^ t]);
}

/// Device timestamps count seconds in a calendar where every month has 31 days, from 2000.
int zkEncodeTime(DateTime t) => (((t.year % 100) * 12 * 31 + (t.month - 1) * 31 + t.day - 1) * 86400) + (t.hour * 60 + t.minute) * 60 + t.second;

DateTime zkDecodeTime(int t) {
  final second = t % 60;
  t ~/= 60;
  final minute = t % 60;
  t ~/= 60;
  final hour = t % 24;
  t ~/= 24;
  final day = t % 31 + 1;
  t ~/= 31;
  final month = t % 12 + 1;
  t ~/= 12;
  return DateTime(t + 2000, month, day, hour, minute, second);
}

/// Arguments for the buffered read of a table (users, attendance).
Uint8List zkBufferRequest(int command, {int fct = 0, int ext = 0}) {
  final b = ByteData(11)
    ..setInt8(0, 1)
    ..setInt16(1, command, Endian.little)
    ..setInt32(3, fct, Endian.little)
    ..setInt32(7, ext, Endian.little);
  return b.buffer.asUint8List();
}

Uint8List zkInt32Pair(int a, int b) {
  final d = ByteData(8)
    ..setInt32(0, a, Endian.little)
    ..setInt32(4, b, Endian.little);
  return d.buffer.asUint8List();
}

Uint8List zkUint32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

Uint8List zkInt16(int v) => (ByteData(2)..setInt16(0, v, Endian.little)).buffer.asUint8List();

/// A person stored on the terminal. [uid] is the device's internal slot; [userId] is the ID shown on
/// the device ("236"), which the app links to a member.
class ZkUser {
  final int uid;
  final String userId;
  final String name;
  final int privilege;
  final String password;
  final String groupId;
  final int card;

  const ZkUser({required this.uid, required this.userId, required this.name, this.privilege = 0, this.password = '', this.groupId = '', this.card = 0});

  bool get disabled => privilege & zkDisabledBit == zkDisabledBit;

  ZkUser copyWith({String? name, bool? disabled}) => ZkUser(
        uid: uid,
        userId: userId,
        name: name ?? this.name,
        privilege: disabled == null ? privilege : (disabled ? privilege | zkDisabledBit : privilege & ~zkDisabledBit),
        password: password,
        groupId: groupId,
        card: card,
      );
}

String _cString(List<int> bytes) {
  final end = bytes.indexOf(0);
  return latin1.decode(end == -1 ? bytes : bytes.sublist(0, end), allowInvalid: true).trim();
}

List<int> _fixed(String s, int length) {
  final bytes = latin1.encode(s.replaceAll(RegExp(r'[^\x20-\x7E]'), ''));
  return [...bytes.take(length), ...List.filled(length - bytes.length.clamp(0, length), 0)];
}

/// Users table from a buffered read: 4-byte total size, then fixed-size records (72 bytes on
/// current face terminals, 28 on old ones). [userCount] comes from the free-sizes reply.
List<ZkUser> zkParseUsers(Uint8List data, int userCount) {
  if (data.length <= 4 || userCount <= 0) return const [];
  final total = ByteData.sublistView(data).getUint32(0, Endian.little);
  final size = total ~/ userCount;
  final body = data.sublist(4);
  final users = <ZkUser>[];
  for (var o = 0; o + size <= body.length; o += size) {
    final r = body.sublist(o, o + size);
    final b = ByteData.sublistView(r);
    if (size == 28) {
      users.add(ZkUser(
        uid: b.getUint16(0, Endian.little),
        privilege: r[2],
        password: _cString(r.sublist(3, 8)),
        name: _cString(r.sublist(8, 16)),
        card: b.getUint32(16, Endian.little),
        groupId: '${r[21]}',
        userId: '${b.getUint32(24, Endian.little)}',
      ));
    } else {
      users.add(ZkUser(
        uid: b.getUint16(0, Endian.little),
        privilege: r[2],
        password: _cString(r.sublist(3, 11)),
        name: _cString(r.sublist(11, 35)),
        card: b.getUint32(35, Endian.little),
        groupId: _cString(r.sublist(40, 47)),
        userId: _cString(r.sublist(48, 72)),
      ));
    }
  }
  return users;
}

/// Bytes for writing a user (72-byte layout unless the device uses the old 28-byte one).
Uint8List zkPackUser(ZkUser u, {int recordSize = 72}) {
  if (recordSize == 28) {
    final b = ByteData(28)
      ..setUint16(0, u.uid, Endian.little)
      ..setUint8(2, u.privilege);
    final out = b.buffer.asUint8List();
    out.setRange(3, 8, _fixed(u.password, 5));
    out.setRange(8, 16, _fixed(u.name, 8));
    b
      ..setUint32(16, u.card, Endian.little)
      ..setUint8(21, int.tryParse(u.groupId) ?? 0)
      ..setUint16(22, 0, Endian.little)
      ..setUint32(24, int.tryParse(u.userId) ?? u.uid, Endian.little);
    return out;
  }
  final b = ByteData(72)
    ..setUint16(0, u.uid, Endian.little)
    ..setUint8(2, u.privilege);
  final out = b.buffer.asUint8List();
  out.setRange(3, 11, _fixed(u.password, 8));
  out.setRange(11, 35, _fixed(u.name, 24));
  b.setUint32(35, u.card, Endian.little);
  out.setRange(40, 47, _fixed(u.groupId, 7));
  out.setRange(48, 72, _fixed(u.userId, 24));
  return out;
}

/// One door entry from the attendance log.
class ZkEntry {
  final String userId;
  final DateTime time;

  const ZkEntry(this.userId, this.time);
}

/// Attendance log from a buffered read. Record size depends on the firmware (8, 16 or 40 bytes);
/// 8-byte records carry the device slot, so [users] maps it back to the user ID.
List<ZkEntry> zkParseAttendance(Uint8List data, int recordCount, List<ZkUser> users) {
  if (data.length <= 4 || recordCount <= 0) return const [];
  final total = ByteData.sublistView(data).getUint32(0, Endian.little);
  final size = total ~/ recordCount;
  final body = data.sublist(4);
  final byUid = {for (final u in users) u.uid: u.userId};
  final entries = <ZkEntry>[];
  for (var o = 0; o + size <= body.length; o += size) {
    final r = body.sublist(o, o + size);
    final b = ByteData.sublistView(r);
    switch (size) {
      case 8:
        final uid = b.getUint16(0, Endian.little);
        entries.add(ZkEntry(byUid[uid] ?? '$uid', zkDecodeTime(b.getUint32(3, Endian.little))));
      case 16:
        entries.add(ZkEntry('${b.getUint32(0, Endian.little)}', zkDecodeTime(b.getUint32(4, Endian.little))));
      default:
        entries.add(ZkEntry(_cString(r.sublist(2, 26)), zkDecodeTime(b.getUint32(27, Endian.little))));
    }
  }
  return entries;
}

/// Counts from the free-sizes reply. [faces] is what tells us a new face was just enrolled.
class ZkSizes {
  final int users;
  final int fingers;
  final int records;
  final int usersCap;
  final int faces;
  final int facesCap;

  const ZkSizes({this.users = 0, this.fingers = 0, this.records = 0, this.usersCap = 0, this.faces = 0, this.facesCap = 0});

  factory ZkSizes.parse(Uint8List data) {
    if (data.length < 80) return const ZkSizes();
    final b = ByteData.sublistView(data);
    int field(int i) => b.getInt32(i * 4, Endian.little);
    final hasFaces = data.length >= 92;
    return ZkSizes(
      users: field(4),
      fingers: field(6),
      records: field(8),
      usersCap: field(15),
      faces: hasFaces ? b.getInt32(80, Endian.little) : 0,
      facesCap: hasFaces ? b.getInt32(88, Endian.little) : 0,
    );
  }
}
