import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The save layer. One JSON blob under one key.
///
/// docs/HANDOFF.md listed persistence as a known gap: "Mana, companion
/// levels, gear, and now bond/completed-beats are all in-memory only […]
/// Worth a save/load layer before this goes much further, so playtesting
/// progress survives a restart." This is that layer.
///
/// `shared_preferences` rather than a file because it is the one storage
/// that works unchanged on web (localStorage), Android, iOS and desktop —
/// and the web build is what makes this thing playable without a device.
abstract class SaveStore {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> data);
  Future<void> clear();
}

class PrefsSaveStore implements SaveStore {
  static const String key = 'gatefall.save.v1';
  static const String backupKey = 'gatefall.save.v1.backup';

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = _decode(prefs.getString(key));
    if (primary != null) return primary;
    // Recover the last known-good snapshot without overwriting it.
    return _decode(prefs.getString(backupKey));
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve the previous valid save before replacing the primary copy.
    final previous = prefs.getString(key);
    if (_decode(previous) != null) {
      await prefs.setString(backupKey, previous!);
    }
    await prefs.setString(key, jsonEncode(data));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    await prefs.remove(backupKey);
  }
}

/// For tests and for the "play without saving" path.
class MemorySaveStore implements SaveStore {
  Map<String, dynamic>? _data;

  MemorySaveStore([this._data]);

  @override
  Future<Map<String, dynamic>?> load() async => _data;

  @override
  Future<void> save(Map<String, dynamic> data) async => _data = data;

  @override
  Future<void> clear() async => _data = null;
}
