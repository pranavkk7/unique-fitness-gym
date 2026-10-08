import 'dart:typed_data';

import '../models/models.dart';

/// The only place that knows how data is saved. [GymProvider] talks to this interface, so moving to
/// a cloud backend (Firebase, Supabase, a REST API) means writing one new implementation.
abstract class GymStore {
  /// The saved data set, or null on first launch.
  Future<GymData?> load();

  /// Saves one record of a collection (see [Collections]) under its id.
  Future<void> put(String collection, String id, Map<String, dynamic> json);

  Future<void> delete(String collection, String id);

  /// Saves the settings and the member and receipt counters.
  Future<void> putMeta({required GymSettings settings, required int nextMemberNumber, required int nextReceiptNumber});

  /// Replaces everything (demo data, reset, restore from backup). Photos not in [photos] are removed.
  Future<void> replaceAll(GymData data, {Map<String, Uint8List> photos = const {}});

  Future<Uint8List?> loadPhoto(String memberId);

  /// Saves a member photo, or removes it when [bytes] is null.
  Future<void> savePhoto(String memberId, Uint8List? bytes);

  Future<Map<String, Uint8List>> allPhotos();
}

/// Keeps everything in memory. Used by tests and the screenshot generator.
class MemoryGymStore implements GymStore {
  final _records = <String, Map<String, Map<String, dynamic>>>{};
  final _photos = <String, Uint8List>{};
  Map<String, dynamic>? _meta;

  /// Number of single-record writes, so tests can check that a change writes only what it touched.
  int writes = 0;

  @override
  Future<GymData?> load() async {
    if (_meta == null) return null;
    return GymData.fromRecords(
      {for (final c in Collections.all) c: [...?_records[c]?.values]},
      settings: _meta!['settings'] as Map<String, dynamic>?,
      nextMemberNumber: _meta!['nextMemberNumber'] as int,
      nextReceiptNumber: _meta!['nextReceiptNumber'] as int,
    );
  }

  @override
  Future<void> put(String collection, String id, Map<String, dynamic> json) async {
    writes++;
    (_records[collection] ??= {})[id] = json;
  }

  @override
  Future<void> delete(String collection, String id) async {
    writes++;
    _records[collection]?.remove(id);
  }

  @override
  Future<void> putMeta({required GymSettings settings, required int nextMemberNumber, required int nextReceiptNumber}) async {
    _meta = {'settings': settings.toJson(), 'nextMemberNumber': nextMemberNumber, 'nextReceiptNumber': nextReceiptNumber};
  }

  @override
  Future<void> replaceAll(GymData data, {Map<String, Uint8List> photos = const {}}) async {
    _records.clear();
    data.records.forEach((collection, list) => _records[collection] = {for (final j in list) j['id'] as String: j});
    _photos
      ..clear()
      ..addAll(photos);
    await putMeta(settings: data.settings, nextMemberNumber: data.nextMemberNumber, nextReceiptNumber: data.nextReceiptNumber);
  }

  @override
  Future<Uint8List?> loadPhoto(String memberId) async => _photos[memberId];

  @override
  Future<void> savePhoto(String memberId, Uint8List? bytes) async => bytes == null ? _photos.remove(memberId) : _photos[memberId] = bytes;

  @override
  Future<Map<String, Uint8List>> allPhotos() async => Map.of(_photos);
}
