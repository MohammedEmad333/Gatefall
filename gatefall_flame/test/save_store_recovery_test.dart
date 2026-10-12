import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gatefall/state/save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('restores the latest primary save', () async {
    final store = PrefsSaveStore();
    await store.save({'gold': 10});
    await store.save({'gold': 20});
    expect(await store.load(), {'gold': 20});
  });

  test('recovers from corrupt primary using last known-good backup', () async {
    final store = PrefsSaveStore();
    await store.save({'gold': 10});
    await store.save({'gold': 20});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsSaveStore.key, '{corrupt');
    expect(await store.load(), {'gold': 10});
  });

  test('does not overwrite a good backup with corrupt data', () async {
    final store = PrefsSaveStore();
    await store.save({'gold': 10});
    await store.save({'gold': 20});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsSaveStore.key, 'bad');
    await store.save({'gold': 30});
    await prefs.setString(PrefsSaveStore.key, 'bad again');
    expect(await store.load(), {'gold': 10});
  });

  test('clearing saves removes both copies', () async {
    final store = PrefsSaveStore();
    await store.save({'gold': 1});
    await store.save({'gold': 2});
    await store.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefsSaveStore.key), isNull);
    expect(prefs.getString(PrefsSaveStore.backupKey), isNull);
    expect(await store.load(), isNull);
  });

  test('invalid JSON object types fall back to backup', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsSaveStore.key, jsonEncode([1, 2]));
    await prefs.setString(PrefsSaveStore.backupKey, jsonEncode({'gold': 7}));
    expect(await PrefsSaveStore().load(), {'gold': 7});
  });
}
