part of 'gym_provider.dart';

/// Gym setup and safety: plans, trainers, classes, settings, the owner PIN, and backup and restore.
extension GymSetup on GymProvider {
  // ---- plans, trainers, classes, settings --------------------------------------------

  Future<void> savePlan(Plan plan) async {
    final i = _plans.indexWhere((p) => p.id == plan.id);
    i == -1 ? _plans.add(plan) : _plans[i] = plan;
    _put(Collections.plans, plan.id, plan.toJson());
    await _commit();
  }

  String newPlanId() => _newId('p');

  bool planInUse(String id) => _members.any((m) => m.planId == id);

  /// A plan members are on cannot be deleted (retire it instead). Returns false in that case.
  Future<bool> deletePlan(String id) async {
    if (planInUse(id)) return false;
    _plans.removeWhere((p) => p.id == id);
    _delete(Collections.plans, id);
    await _commit();
    return true;
  }

  Future<void> saveTrainer(Trainer t) async {
    final i = _trainers.indexWhere((x) => x.id == t.id);
    i == -1 ? _trainers.add(t) : _trainers[i] = t;
    _put(Collections.trainers, t.id, t.toJson());
    await _commit();
  }

  String newTrainerId() => _newId('t');

  Future<void> deleteTrainer(String id) async {
    _trainers.removeWhere((t) => t.id == id);
    _delete(Collections.trainers, id);
    // Members and classes keep working without a trainer.
    for (var i = 0; i < _members.length; i++) {
      if (_members[i].trainerId == id) {
        _members[i] = _members[i].copyWith(clearTrainer: true);
        _put(Collections.members, _members[i].id, _members[i].toJson());
      }
    }
    for (var i = 0; i < _classes.length; i++) {
      if (_classes[i].trainerId == id) {
        _classes[i] = _classes[i].copyWith(clearTrainer: true);
        _put(Collections.classes, _classes[i].id, _classes[i].toJson());
      }
    }
    await _commit();
  }

  List<Member> clientsOf(String trainerId) => _members.where((m) => m.trainerId == trainerId && isRunning(m)).toList();

  Future<void> saveClass(GymClass c) async {
    final i = _classes.indexWhere((x) => x.id == c.id);
    i == -1 ? _classes.add(c) : _classes[i] = c;
    _put(Collections.classes, c.id, c.toJson());
    await _commit();
  }

  String newClassId() => _newId('c');

  Future<void> deleteClass(String id) async {
    _classes.removeWhere((c) => c.id == id);
    _delete(Collections.classes, id);
    await _commit();
  }

  /// Classes on a weekday (DateTime.monday..sunday), earliest first.
  List<GymClass> classesOn(int weekday) => _classes.where((c) => c.weekdays.contains(weekday)).toList()..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  Future<void> updateSettings(GymSettings s) async {
    _settings = s;
    _metaDirty = true;
    await _commit();
  }

  // ---- owner PIN ---------------------------------------------------------------------

  /// Front-desk staff can use the app without the PIN; revenue, expenses, settings and deleting
  /// need the owner's PIN once one is set.
  bool get ownerUnlocked => !_settings.hasPin || _unlocked;

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw ArgumentError('The PIN must be 4 digits');
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    _unlocked = true;
    await updateSettings(_settings.copyWith(pinHash: _hash(salt, pin), pinSalt: salt));
  }

  Future<void> clearPin() => updateSettings(_settings.copyWith(clearPin: true));

  bool unlock(String pin) {
    if (!_settings.hasPin) return true;
    final ok = _hash(_settings.pinSalt!, pin) == _settings.pinHash;
    if (ok && !_unlocked) {
      _unlocked = true;
      _notify();
    }
    return ok;
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    _notify();
  }

  // ---- backup ------------------------------------------------------------------------

  static const _backupApp = 'unique_fitness_gym';

  /// Everything, photos included, as one JSON document the owner can keep in Drive or WhatsApp.
  Future<String> exportBackup() async {
    final photos = await _store.allPhotos();
    return jsonEncode({
      'app': _backupApp,
      'exportedAt': _clock().toIso8601String(),
      'data': snapshot.toJson(),
      'photos': {for (final e in photos.entries) e.key: base64Encode(e.value)},
    });
  }

  /// Replaces all data with a backup. Throws [FormatException] if the file is not a backup from
  /// this app, and changes nothing in that case.
  Future<int> restoreBackup(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('This file is not a backup.');
    }
    if (decoded is! Map || decoded['app'] != _backupApp || decoded['data'] is! Map) {
      throw const FormatException('This file is not a Unique Fitness Gym backup.');
    }
    final data = GymData.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
    final photos = <String, Uint8List>{};
    if (decoded['photos'] is Map) {
      (decoded['photos'] as Map).forEach((key, value) {
        if (key is String && value is String) {
          try {
            photos[key] = base64Decode(value);
          } catch (_) {/* skip a damaged photo, keep the rest */}
        }
      });
    }
    await _replaceAll(data, photos: photos);
    return data.members.length;
  }
}
