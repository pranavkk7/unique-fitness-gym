import 'dart:convert';
import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../models/models.dart';
import 'gym_store.dart';

/// Saves data on the device with Hive (files on Android and iOS, IndexedDB on the web).
///
/// Every collection is its own box and every record is stored as a JSON string under its id. A
/// check-in or payment therefore writes one small record, so saving stays fast however many years
/// of history the gym builds up. Photos live in a lazy box and are only read when shown.
class HiveGymStore implements GymStore {
  static const _prefix = 'ufg_';
  static const _metaKey = 'meta';

  final Map<String, Box<String>> _boxes = {};
  late Box<String> _meta;
  late LazyBox<Uint8List> _photos;
  bool _open = false;

  /// Opens every box. Call `Hive.initFlutter()` (or `Hive.init(path)` in tests) first.
  Future<void> open() async {
    if (_open) return;
    for (final c in Collections.all) {
      _boxes[c] = await Hive.openBox<String>('$_prefix$c');
    }
    _meta = await Hive.openBox<String>('${_prefix}meta');
    _photos = await Hive.openLazyBox<Uint8List>('${_prefix}photos');
    _open = true;
  }

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null; // one damaged record must not stop the app from opening
    }
  }

  @override
  Future<GymData?> load() async {
    await open();
    final meta = _decode(_meta.get(_metaKey));
    if (meta == null) return null;
    return GymData.fromRecords(
      {
        for (final c in Collections.all) c: [for (final raw in _boxes[c]!.values) ?_decode(raw)],
      },
      settings: meta['settings'] is Map<String, dynamic> ? meta['settings'] as Map<String, dynamic> : null,
      nextMemberNumber: (meta['nextMemberNumber'] as num?)?.toInt() ?? 1,
      nextReceiptNumber: (meta['nextReceiptNumber'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  Future<void> put(String collection, String id, Map<String, dynamic> json) => _boxes[collection]!.put(id, jsonEncode(json));

  @override
  Future<void> delete(String collection, String id) => _boxes[collection]!.delete(id);

  @override
  Future<void> putMeta({required GymSettings settings, required int nextMemberNumber, required int nextReceiptNumber}) => _meta.put(
        _metaKey,
        jsonEncode({'schemaVersion': GymData.schemaVersion, 'settings': settings.toJson(), 'nextMemberNumber': nextMemberNumber, 'nextReceiptNumber': nextReceiptNumber}),
      );

  @override
  Future<void> replaceAll(GymData data, {Map<String, Uint8List> photos = const {}}) async {
    await open();
    for (final entry in data.records.entries) {
      final box = _boxes[entry.key]!;
      await box.clear();
      await box.putAll({for (final j in entry.value) j['id'] as String: jsonEncode(j)});
    }
    await _photos.clear();
    if (photos.isNotEmpty) await _photos.putAll(photos);
    await putMeta(settings: data.settings, nextMemberNumber: data.nextMemberNumber, nextReceiptNumber: data.nextReceiptNumber);
  }

  @override
  Future<Uint8List?> loadPhoto(String memberId) => _photos.get(memberId);

  @override
  Future<void> savePhoto(String memberId, Uint8List? bytes) => bytes == null ? _photos.delete(memberId) : _photos.put(memberId, bytes);

  @override
  Future<Map<String, Uint8List>> allPhotos() async {
    final result = <String, Uint8List>{};
    for (final key in _photos.keys) {
      final bytes = await _photos.get(key);
      if (bytes != null) result[key as String] = bytes;
    }
    return result;
  }
}
