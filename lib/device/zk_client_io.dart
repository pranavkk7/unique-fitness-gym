import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'access_device.dart';
import 'zk_protocol.dart';

/// Connects to an eSSL/ZKTeco terminal over TCP.
Future<AccessDevice> connectZkDevice(DeviceConfig config) => ZkAccessDevice.connect(config);

/// TCP client for the ZK protocol: sends one command at a time and reads complete frames.
class ZkAccessDevice implements AccessDevice {
  final Socket _socket;
  final _bytes = <int>[];
  final _frames = Queue<Uint8List>();
  Completer<void>? _arrived;
  Object? _socketError;
  int _session = 0;
  int _reply = 65534;
  int _userRecordSize = 72;
  static const _timeout = Duration(seconds: 8);
  static const _maxChunk = 0xFFC0;

  ZkAccessDevice._(this._socket) {
    _socket.listen(
      (data) {
        _bytes.addAll(data);
        _splitFrames();
        _wake();
      },
      onError: (Object e) {
        _socketError = e;
        _wake();
      },
      onDone: () {
        _socketError ??= const ZkException('The device closed the connection');
        _wake();
      },
    );
  }

  static Future<ZkAccessDevice> connect(DeviceConfig config) async {
    final Socket socket;
    try {
      socket = await Socket.connect(config.host.trim(), config.port, timeout: const Duration(seconds: 5));
    } on SocketException catch (e) {
      throw ZkException('Could not reach the device at ${config.host}:${config.port}. Is the phone on the gym Wi-Fi? (${e.message})');
    }
    socket.setOption(SocketOption.tcpNoDelay, true);
    final d = ZkAccessDevice._(socket);
    try {
      var r = await d._send(ZkCommand.connect);
      d._session = r.sessionId;
      if (r.code == ZkReply.unauthorized) {
        r = await d._send(ZkCommand.auth, zkCommKey(config.commKey, d._session));
        if (r.code == ZkReply.unauthorized) throw const ZkException('Wrong device password (comm key)');
      }
      if (!r.ok) throw ZkException('The device refused the connection (code ${r.code})');
    } catch (_) {
      socket.destroy();
      rethrow;
    }
    return d;
  }

  void _wake() {
    final c = _arrived;
    _arrived = null;
    c?.complete();
  }

  void _splitFrames() {
    while (_bytes.length >= 8) {
      final length = zkFrameLength(_bytes);
      if (_bytes.length < 8 + length) return;
      _frames.add(Uint8List.fromList(_bytes.sublist(8, 8 + length)));
      _bytes.removeRange(0, 8 + length);
    }
  }

  Future<ZkResponse> _next() async {
    while (_frames.isEmpty) {
      if (_socketError != null) throw _socketError is ZkException ? _socketError! : ZkException('Connection lost: $_socketError');
      _arrived ??= Completer<void>();
      await _arrived!.future.timeout(_timeout, onTimeout: () => throw const ZkException('The device did not answer in time'));
    }
    return ZkResponse.parse(_frames.removeFirst());
  }

  Future<ZkResponse> _send(int command, [List<int> data = const []]) async {
    _socket.add(zkTcpFrame(zkPacket(command, data, _session, _reply)));
    final r = await _next();
    _reply = r.replyId;
    return r;
  }

  Future<ZkResponse> _expectOk(int command, [List<int> data = const []]) async {
    final r = await _send(command, data);
    if (!r.ok) throw ZkException('Command $command failed (code ${r.code})');
    return r;
  }

  /// Reads a whole table: small tables come back at once; big ones in chunks.
  Future<Uint8List> _readBuffer(int command, {int fct = 0}) async {
    final r = await _expectOk(ZkCommand.prepareBuffer, zkBufferRequest(command, fct: fct));
    if (r.code == ZkReply.data) return r.data;
    final size = ByteData.sublistView(r.data).getUint32(1, Endian.little);
    final out = BytesBuilder(copy: false);
    for (var start = 0; start < size; start += _maxChunk) {
      out.add(await _readChunk(start, (size - start).clamp(0, _maxChunk)));
    }
    await _send(ZkCommand.freeData);
    return out.takeBytes();
  }

  Future<Uint8List> _readChunk(int start, int size) async {
    final r = await _expectOk(ZkCommand.readBuffer, zkInt32Pair(start, size));
    if (r.code == ZkReply.data) return r.data;
    // PREPARE_DATA: the chunk follows in one or more DATA frames, then an OK frame.
    final total = ByteData.sublistView(r.data).getUint32(0, Endian.little);
    final out = BytesBuilder(copy: false);
    while (out.length < total) {
      final part = await _next();
      if (part.code == ZkReply.data) out.add(part.data);
    }
    final done = await _next();
    _reply = done.replyId;
    return out.takeBytes();
  }

  Future<ZkSizes> _sizes() async => ZkSizes.parse((await _expectOk(ZkCommand.getFreeSizes)).data);

  @override
  Future<DeviceInfo> info() async => DeviceInfo.fromSizes(await _sizes());

  @override
  Future<List<ZkUser>> users() async {
    final sizes = await _sizes();
    if (sizes.users == 0) return const [];
    final data = await _readBuffer(ZkCommand.userTempRead, fct: ZkCommand.fctUser);
    if (data.length > 4) _userRecordSize = ByteData.sublistView(data).getUint32(0, Endian.little) ~/ sizes.users;
    return zkParseUsers(data, sizes.users);
  }

  @override
  Future<void> saveUser(ZkUser user) async {
    await _expectOk(ZkCommand.userWrite, zkPackUser(user, recordSize: _userRecordSize));
    await _send(ZkCommand.refreshData);
  }

  @override
  Future<void> deleteUser(int uid) async {
    await _expectOk(ZkCommand.deleteUser, zkInt16(uid));
    await _send(ZkCommand.refreshData);
  }

  @override
  Future<List<ZkEntry>> entries() async {
    final sizes = await _sizes();
    if (sizes.records == 0) return const [];
    final users = await this.users();
    return zkParseAttendance(await _readBuffer(ZkCommand.attLogRead), sizes.records, users);
  }

  @override
  Future<void> setTime(DateTime time) => _expectOk(ZkCommand.setTime, zkUint32(zkEncodeTime(time)));

  @override
  Future<void> close() async {
    try {
      await _send(ZkCommand.exit).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Closing anyway.
    }
    _socket.destroy();
  }
}
