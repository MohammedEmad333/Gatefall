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

  @override
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // A corrupt save is not worth crashing a player's session over —
      // start fresh rather than wedging the app on every launch.
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
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
