import 'dart:io';

/// `flutter test` sets FLUTTER_TEST in the environment of the process it
/// runs the test in. That is the whole detection — no test-only import
/// leaking into the app, and nothing to remember to set.
bool get runningUnderTest => Platform.environment.containsKey('FLUTTER_TEST');
